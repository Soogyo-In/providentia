import 'dart:convert';
import 'dart:io';

import 'package:googleapis/aiplatform/v1.dart';
import 'package:googleapis_auth/auth_io.dart';

import '../environments.dart';

/// A service class to handle the business logic for processing ledger data.
/// This encapsulates the steps detailed in the 'process_ledger_data_sequence.mmd' diagram.
class LedgerService {
  final AiplatformApi _aiplatformApi;

  LedgerService(AutoRefreshingAuthClient client)
    : _aiplatformApi = AiplatformApi(client);

  Future<List<OrganizeFilesByMonthResponse>> organizeFilesByMonth(
    List<(String name, String id)> fileNameAndId,
  ) async {
    final organizeFilesByMonthPrompt =
        '''
      You are a file organization expert.
      Your task is to group a list of file IDs by month in 'yyyy-MM' format based on their names.
      List of shared files (file name, file id): $fileNameAndId
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
                      'fileIds': GoogleCloudAiplatformV1Schema(
                        type: 'ARRAY',
                        items: GoogleCloudAiplatformV1Schema(
                          type: 'STRING',
                          description: '파일 ID 목록',
                        ),
                      ),
                    },
                  ),
                  default_: [],
                  example: [
                    {
                      'month': '2023-02',
                      'fileIds': ['file_id3'],
                    },
                    {
                      'month': '2023-01',
                      'fileIds': ['file_id1', 'file_id2'],
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
}

class OrganizeFilesByMonthResponse {
  final String month;
  final List<String> fileIds;

  OrganizeFilesByMonthResponse({required this.month, required this.fileIds});

  factory OrganizeFilesByMonthResponse.fromJson(Map<String, dynamic> json) {
    return OrganizeFilesByMonthResponse(
      month: json['month'] as String,
      fileIds: List<String>.from(json['fileIds'] as List),
    );
  }

  Map<String, dynamic> toJson() {
    return {'month': month, 'fileIds': fileIds};
  }
}
