import 'dart:convert';
import 'dart:io';

import 'package:googleapis/cloudtasks/v2.dart';
import 'package:googleapis/datastore/v1.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:shelf/shelf.dart';

import '../environments.dart';
import '../router.dart';

const _location = 'asia-northeast3';
const _queueName = 'google-drive-watch-queue';
const _taskParent =
    'projects/$projectId/locations/$_location/queues/$_queueName';
const _retryDelayMinutes = 5;

Future<Response> watchGoogleDriveHandler(Request req) async {
  final AutoRefreshingAuthClient client;
  try {
    client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(json.decode(credentials)),
      [
        DriveApi.driveReadonlyScope,
        CloudTasksApi.cloudTasksScope,
        DatastoreApi.datastoreScope,
      ],
    );
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to initialize Google API client: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final driveApi = DriveApi(client);
  final datastoreApi = DatastoreApi(client);

  final String driveStartPageToken;
  final String? datastoreStartPageToken;
  try {
    final results = await Future.wait([
      _getStartPageTokenFromDrive(driveApi),
      _getStartPageTokenFromDatastore(datastoreApi),
    ]);

    driveStartPageToken = results[0]!;
    datastoreStartPageToken = results[1];
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to retrieve startPageTokens: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final cloudTasksApi = CloudTasksApi(client);

  final isTokenMismatch =
      datastoreStartPageToken != null &&
      driveStartPageToken != datastoreStartPageToken;
  if (isTokenMismatch) {
    try {
      await _scheduleRetryTask(cloudTasksApi);

      return Response(
        202,
        body:
            'startPageToken mismatch detected. Retry scheduled after $_retryDelayMinutes minutes.',
        headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
      );
    } catch (e) {
      return Response.internalServerError(
        body: 'Failed to schedule retry task: $e',
        headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
      );
    }
  }

  try {
    await _setStartPageTokenInDatastore(datastoreApi, driveStartPageToken);

    final channel = await _setupDriveWatch(driveApi, driveStartPageToken);

    await _scheduleRenewalTask(cloudTasksApi, channel);

    return Response.ok(
      'Google Drive watch set up successfully. Channel ID: ${channel.id}',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to set up Google Drive watch: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }
}

Future<String> _getStartPageTokenFromDrive(DriveApi driveApi) async {
  final token = await driveApi.changes.getStartPageToken().then(
    (response) => response.startPageToken,
  );

  if (token == null) {
    throw Exception('No start page token found in Drive API');
  }

  return token;
}

Future<String?> _getStartPageTokenFromDatastore(
  DatastoreApi datastoreApi,
) async {
  try {
    final response = await datastoreApi.projects.lookup(
      LookupRequest(
        keys: [
          Key(
            path: [PathElement(kind: 'DrivePageTokenState', name: 'global')],
          ),
        ],
      ),
      projectId,
    );

    final entity = response.found?.first.entity;
    return entity?.properties?['lastPageToken']?.stringValue;
  } catch (e) {
    throw Exception('Failed to retrieve start page token from Datastore: $e');
  }
}

Future<void> _setStartPageTokenInDatastore(
  DatastoreApi datastoreApi,
  String startPageToken,
) async {
  await datastoreApi.projects.commit(
    CommitRequest(
      mode: 'NON_TRANSACTIONAL',
      mutations: [
        Mutation(
          upsert: Entity(
            key: Key(
              path: [PathElement(kind: 'DrivePageTokenState', name: 'global')],
            ),
            properties: {
              'lastPageToken': Value(stringValue: startPageToken),
              'updatedAt': Value(
                timestampValue: DateTime.now().toUtc().toIso8601String(),
              ),
            },
          ),
        ),
      ],
    ),
    projectId,
  );
}

Future<Channel> _setupDriveWatch(
  DriveApi driveApi,
  String startPageToken,
) async {
  final channelId = '$projectId-${DateTime.now().millisecondsSinceEpoch}';

  final channel = await driveApi.changes.watch(
    Channel(
      id: channelId,
      type: 'web_hook',
      address: Route.generateMonthlyLedgerFromDrive
          .buildUrl(serviceUrl)
          .toString(),
      token: googleDriveChannelToken,
      expiration: DateTime.now()
          .toUtc()
          .add(Duration(days: 7))
          .millisecondsSinceEpoch
          .toString(),
    ),
    startPageToken,
    supportsAllDrives: true,
  );

  return channel;
}

Future<void> _scheduleRetryTask(CloudTasksApi cloudTasksApi) async {
  final scheduleTime = DateTime.now().toUtc().add(
    Duration(minutes: _retryDelayMinutes),
  );

  await cloudTasksApi.projects.locations.queues.tasks.create(
    CreateTaskRequest(
      task: Task(
        name:
            '$_taskParent/tasks/retry-${DateTime.now().millisecondsSinceEpoch}',
        httpRequest: HttpRequest(
          httpMethod: 'POST',
          url: Route.watchGoogleDrive.buildUrl(serviceUrl).toString(),
        ),
        scheduleTime: scheduleTime.toIso8601String(),
      ),
    ),
    _taskParent,
  );
}

Future<void> _scheduleRenewalTask(
  CloudTasksApi cloudTasksApi,
  Channel channel,
) async {
  final expiration = channel.expiration;
  if (expiration == null) {
    throw Exception('Channel expiration is null, cannot schedule renewal task');
  }

  final scheduleTime = DateTime.fromMillisecondsSinceEpoch(
    int.parse(expiration),
    isUtc: true,
  ).subtract(Duration(hours: 1));

  await cloudTasksApi.projects.locations.queues.tasks.create(
    CreateTaskRequest(
      task: Task(
        name: '$_taskParent/tasks/renewal-${channel.id}',
        httpRequest: HttpRequest(
          httpMethod: 'POST',
          url: Route.watchGoogleDrive.buildUrl(serviceUrl).toString(),
        ),
        scheduleTime: scheduleTime.toIso8601String(),
      ),
    ),
    _taskParent,
  );
}
