import 'dart:convert';
import 'dart:io';

import 'package:googleapis/datastore/v1.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:shelf/shelf.dart';

import '../environments.dart';

Future<Response> generateMonthlyLedgerFromDriveHandler(Request req) async {
  final AutoRefreshingAuthClient client;
  try {
    client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(jsonDecode(credentials)),
      [DriveApi.driveReadonlyScope, DatastoreApi.datastoreScope],
    );
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to initialize Google API client: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final driveApi = DriveApi(client);
  final channelId = req.headers['x-goog-channel-id'];
  if (channelId == null) {
    return Response.badRequest(
      body: 'Missing channel id.',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  if (req.headers['x-goog-channel-token'] != googleDriveChannelToken) {
    try {
      await driveApi.channels.stop(Channel(id: channelId));
    } catch (e) {
      return Response.internalServerError(
        body: 'Failed to stop channel: $e',
        headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
      );
    }

    return Response.unauthorized(
      'Invalid channel token.',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final lookupResponse = await DatastoreApi(client).projects.lookup(
    LookupRequest(
      keys: [
        Key(
          partitionId: PartitionId(projectId: projectId),
          path: [PathElement(kind: 'DrivePageTokenState', name: 'global')],
        ),
      ],
    ),
    projectId,
  );

  final pageToken = lookupResponse
      .found
      ?.firstOrNull
      ?.entity
      ?.properties?['lastPageToken']
      ?.stringValue;
  if (pageToken == null) {
    return Response.internalServerError(
      body: 'No page token found in Datastore.',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final changes = await driveApi.changes.list(
    pageToken,
    supportsAllDrives: true,
  );
  print('Changes: ${changes.changes?.length}');

  return Response.ok(
    'Channel token is valid.',
    headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
  );
}
