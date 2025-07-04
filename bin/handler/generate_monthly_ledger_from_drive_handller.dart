import 'dart:convert';
import 'dart:io';

import 'package:googleapis/aiplatform/v1.dart';
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

  final startPageToken = await driveApi.changes
      .getStartPageToken(supportsAllDrives: true)
      .then((e) => e.startPageToken);

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
      ?.properties?['lastestPageToken']
      ?.stringValue;
  if (pageToken == null) {
    return Response.internalServerError(
      body: 'No page token found in Datastore.',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final getSharedRootFolderQuery =
      "mimeType = 'application/vnd.google-apps.folder' and sharedWithMe";

  final sharedRootFolders = await driveApi.files
      .list(q: getSharedRootFolderQuery, spaces: 'drive', $fields: 'files(id)')
      .then((e) => e.files ?? []);

  final sharedFolderIds = <String>[];
  final folderStack = sharedRootFolders;
  while (folderStack.isNotEmpty) {
    final folder = folderStack.removeLast();

    sharedFolderIds.add(folder.id!);

    // If not found, check for subfolders
    final subFolders = await driveApi.files
        .list(
          q: "mimeType = 'application/vnd.google-apps.folder' and '${folder.id}' in parents",
          spaces: 'drive',
          $fields: 'files(id)',
        )
        .then((e) => e.files ?? []);
    folderStack.addAll(subFolders);
  }

  if (sharedFolderIds.isEmpty) return Response.ok(null);

  final sharedFiles = await driveApi.files
      .list(
        q: "'${sharedFolderIds.join("' in parents or '")}' in parents",
        spaces: 'drive',
        $fields: 'files(id, name)',
      )
      .then((e) => e.files ?? []);

  if (sharedFiles.isEmpty) return Response.ok(null);

  final fileNameAndId = sharedFiles.map((e) => (e.name, e.id)).toList();
  final organizeFilesByMonthPrompt =
      '''
당신은 파일 정리 전문가입니다.
당신의 임무는 Google Drive에서 공유된 폴더와 파일 목록을 받아서, 각 파일의 ID를 yyyy-MM 형식으로 묶는 것입니다.
공유 파일 목록(파일명, 파일 id): $fileNameAndId
''';

  final aiplatformApi = AiplatformApi(client);
  final response = await aiplatformApi.endpoints.generateContent(
    GoogleCloudAiplatformV1GenerateContentRequest(
      contents: [
        GoogleCloudAiplatformV1Content(
          parts: [
            GoogleCloudAiplatformV1Part(text: organizeFilesByMonthPrompt),
          ],
        ),
      ],
      generationConfig: GoogleCloudAiplatformV1GenerationConfig(
        responseMimeType: ContentType.json.mimeType,
        responseSchema: GoogleCloudAiplatformV1Schema(
          type: "OBJECT",
          description: "내림차순으로 정렬된 yyyy-MM 별로 묶인 파일 ID 목록",
          default_: {},
          example: {
            "2023-02": ["file_id3"],
            "2023-01": ["file_id1", "file_id2"],
          },
        ),
      ),
    ),
    'gemini-2.0-flash-lite',
  );

  final feedback = response.promptFeedback;
  if (feedback != null) {
    return Response.badRequest(
      body:
          'Prompt feedback indicates an issue: ${feedback.blockReasonMessage}',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final candidates = response.candidates;
  if (candidates == null || candidates.isEmpty) {
    return Response.internalServerError(
      body: 'Failed to generate content from AI platform.',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final json = candidates.first.content?.parts?.firstOrNull?.text;
  if (json == null) {
    return Response.internalServerError(
      body: 'No content generated from AI platform.',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final Map<String, List<String>> monthlyFiles;
  try {
    monthlyFiles = jsonDecode(json) as Map<String, List<String>>;
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to parse JSON response: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  // Implement the logic to generate monthly budget from Google Drive data
  // This is a placeholder for the actual implementation
  return Response.ok(
    'Monthly budget generated successfully.',
    headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
  );
}


// a, b, c, d
//
// 초기 구독 시 현재 작업중인 페이지 토큰이 없음. 하지만 start page token 이 마지막 토큰으로 설정됨
// current -
// last a
//
// changes b (변경 시점의 start page token)
//
// current a last 를 current 에 할당해줌.
// last d current 을 기점으로 생기는 변경사항 중 가장 마지막 변경사항의 페이지 토큰을 last 로 설정 (현시점 b)
// 
// changes c (변경 시점의 start page token)
//
// current a 아직 작업이 진행중이므로 별다른 동작을 하지않고 동작 종료.
// last b
//
// changes d (변경 시점의 start page token)
//
// current a 마찬가지로 아직 작업이 진행중이므로 별다른 동작을 하지않고 동작 종료.
// last b
//
// change e (변경 시점의 start page token)
//
// current b 작업이 끝나 새로운 작업을 진행 가능 마지막 page token을 current 에 할당. 변경사항 c, d, e 에 대한 작업을 수행.
// last e current 을 기점으로 생기는 변경사항 중 가장 마지막 변경사항의 페이지 토큰을 last 로 설정 (현시점 e)

