import 'dart:convert';
import 'dart:io';

import 'package:googleapis/aiplatform/v1.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis_auth/auth_io.dart';

import '../../environments.dart';
import '../../google_drive_mime_type.dart';
import '../../spreadsheet_converter.dart';
import 'ledger_service.dart';

/// A service class to handle the business logic for processing ledger data.
/// This encapsulates the steps detailed in the 'process_ledger_data_sequence.mmd' diagram.
class DefaultLedgerService implements LedgerService {
  final DriveApi _driveApi;
  final AiplatformApi _aiplatformApi;

  DefaultLedgerService(AutoRefreshingAuthClient client)
    : _driveApi = DriveApi(client),
      _aiplatformApi = AiplatformApi(client);

  @override
  Future<List<(String name, String id, String mimeType)>>
  getSpreadSheets() async {
    final response = await _driveApi.files.list(
      q:
          "mimeType='application/vnd.google-apps.spreadsheet'"
          " or mimeType='application/vnd.ms-excel'"
          " or mimeType='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'",
      supportsAllDrives: true,
      $fields: 'files(id, name, mimeType)',
    );

    final fileMetadata = <(String, String, String)>[];

    final files = response.files;
    if (files == null || files.isEmpty) return [];

    for (final file in files) {
      final name = file.name;
      final id = file.id;
      final mimeType = file.mimeType;
      if (name == null || id == null || mimeType == null) continue;

      fileMetadata.add((name, id, mimeType));
    }

    return fileMetadata;
  }

  @override
  Future<List<OrganizeFilesByMonthResponse>> organizeFilesByMonth(
    List<(String name, String id, String mimeType)> fileMetadata,
  ) async {
    final organizeFilesByMonthPrompt =
        '''
      You are a file organization expert.
      Your task is to group a list of file IDs by month in 'yyyy-MM' format based on their names.
      List of shared files (file name, file id, mime type): $fileMetadata
    ''';

    final endpoint =
        'projects/$projectId/locations/global/publishers/google/models/gemini-2.0-flash-lite-001';

    final GoogleCloudAiplatformV1GenerateContentResponse aiResponse;
    try {
      aiResponse = await _aiplatformApi.projects.locations.publishers.models
          .generateContent(
            GoogleCloudAiplatformV1GenerateContentRequest(
              contents: [
                GoogleCloudAiplatformV1Content(
                  parts: [
                    GoogleCloudAiplatformV1Part(
                      text: organizeFilesByMonthPrompt,
                    ),
                  ],
                  role: 'user',
                ),
              ],
              generationConfig: GoogleCloudAiplatformV1GenerationConfig(
                responseMimeType: ContentType.json.mimeType,
                responseSchema: GoogleCloudAiplatformV1Schema(
                  type: 'ARRAY',
                  description: '내림차순으로 정렬된 yyyy-MM 별로 묶인 파일 ID 목록',
                  items: GoogleCloudAiplatformV1Schema(
                    type: 'OBJECT',
                    description: '월별 파일 ID 목록',
                    properties: {
                      'month': GoogleCloudAiplatformV1Schema(
                        type: 'STRING',
                        description: '파일이 속한 월 (yyyy-MM 형식)',
                      ),
                      'files': GoogleCloudAiplatformV1Schema(
                        type: 'ARRAY',
                        description: '파일 목록',
                        items: GoogleCloudAiplatformV1Schema(
                          type: 'OBJECT',
                          properties: {
                            'id': GoogleCloudAiplatformV1Schema(
                              type: 'STRING',
                              description: '파일 ID',
                            ),
                            'mimeType': GoogleCloudAiplatformV1Schema(
                              type: 'STRING',
                              description: '파일 MIME 타입',
                            ),
                          },
                        ),
                      ),
                    },
                  ),
                  default_: [],
                  example: [
                    {
                      'month': '2023-02',
                      'files': [
                        {
                          'id': 'file_id3',
                          'mimeType': 'application/vnd.google-apps.spreadsheet',
                        },
                      ],
                    },
                    {
                      'month': '2023-01',
                      'files': [
                        {
                          'id': 'file_id1',
                          'mimeType': 'application/vnd.ms-excel',
                        },
                        {
                          'id': 'file_id2',
                          'mimeType':
                              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                        },
                      ],
                    },
                  ],
                  format: endpoint,
                ),
              ),
            ),
            endpoint,
          );
    } catch (e) {
      throw Exception('Failed to generate content with Vertex AI: $e');
    }

    final jsonText =
        aiResponse.candidates?.firstOrNull?.content?.parts?.firstOrNull?.text ??
        '';

    if (jsonText.isEmpty) {
      throw Exception(
        'Received empty response from Vertex AI for file grouping.',
      );
    }

    return (jsonDecode(jsonText) as List)
        .cast<Map<String, dynamic>>()
        .map(OrganizeFilesByMonthResponse.fromJson)
        .toList();
  }

  @override
  Future<Csv> exportFileToCsv(String fileId, String mimeType) async {
    final Media media;
    if (mimeType == GoogleDriveMimeType.spreadsheet.mimeType) {
      media =
          await _driveApi.files.export(
                fileId,
                'text/csv',
                downloadOptions: DownloadOptions.fullMedia,
              )
              as Media;
    } else if (mimeType ==
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
        mimeType == 'application/vnd.ms-excel') {
      final copy = await _driveApi.files.copy(
        File(mimeType: GoogleDriveMimeType.spreadsheet.mimeType),
        fileId,
        supportsAllDrives: true,
      );

      final copiedFileId = copy.id;
      if (copiedFileId == null) {
        throw Exception('Failed to copy file: $fileId');
      }

      media =
          await _driveApi.files.export(
                copiedFileId,
                'text/csv',
                downloadOptions: DownloadOptions.fullMedia,
              )
              as Media;
    } else {
      throw Exception('Unsupported file type: $mimeType for file: $fileId');
    }

    final bytes = await media.stream.expand((e) => e).toList();
    final csvString = utf8.decode(bytes);
    final rows = csvString.split('\n');

    return Csv(
      rowsCount: rows.length,
      columnsCount: rows.first.split(',').length,
      cells: rows.expand((r) => r.split(',')).toList(),
    );
  }
}
