import 'dart:convert';
import 'dart:io';

import 'package:googleapis/cloudtasks/v2.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:shelf/shelf.dart';

import '../environments.dart';
import '../router.dart';

const _location = 'asia-northeast3';
const _queueName = 'google-drive-webhook-refresh-queue';
const _taskParent =
    'projects/$projectId/locations/$_location/queues/$_queueName';

Future<Response> googleDriveWatchHandler(Request req) async {
  final AutoRefreshingAuthClient client;
  try {
    client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(json.decode(credentials)),
      [DriveApi.driveReadonlyScope, CloudTasksApi.cloudTasksScope],
    );
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to initialize Google API client: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final driveApi = DriveApi(client);

  final String startPageToken;
  try {
    final changes = driveApi.changes;
    final token = await changes.getStartPageToken().then(
      (e) => e.startPageToken,
    );
    if (token == null) {
      return Response.internalServerError(
        body: 'No start page token found in Drive API.',
        headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
      );
    }

    startPageToken = token;
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to get start page token from Drive API: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final channelId = '$projectId-${DateTime.now().millisecondsSinceEpoch}';
  final Channel channel;
  try {
    channel = await driveApi.changes.watch(
      Channel(
        id: channelId,
        type: 'web_hook',
        address: Route.generateMonthlyLedgerFromDrive
            .buildUrl(serviceUrl)
            .toString(),
        token: googleDriveChannelToken,
      ),
      startPageToken,
      supportsAllDrives: true,
    );
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to set up watch on Google Drive changes: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final expiration = channel.expiration;
  if (expiration == null) {
    return Response.internalServerError(
      body: 'Channel expiration is null, cannot schedule task.',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final scheduleTime = DateTime.fromMillisecondsSinceEpoch(
    int.parse(expiration),
    isUtc: true,
  ).subtract(Duration(hours: 1));

  try {
    await CloudTasksApi(client).projects.locations.queues.tasks.create(
      CreateTaskRequest(
        task: Task(
          name: '$_taskParent/tasks/${channel.id}',
          httpRequest: HttpRequest(
            httpMethod: 'POST',
            url: Route.watchGoogleDrive.buildUrl(serviceUrl).toString(),
          ),
          scheduleTime: scheduleTime.toIso8601String(),
        ),
      ),
      _taskParent,
    );
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to create Cloud Task: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  return Response.ok(
    'Google Drive watch set up successfully. Channel ID: $channelId',
    headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
  );
}
