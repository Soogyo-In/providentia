import 'dart:convert';
import 'dart:io';

import 'package:googleapis/aiplatform/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import './ledger_service.dart';

import '../../environments.dart';

/// A service class to handle the business logic for processing ledger data.
/// This encapsulates the steps detailed in the 'process_ledger_data_sequence.mmd' diagram.
class DefaultLedgerService implements LedgerService {
  final AiplatformApi _aiplatformApi;

  DefaultLedgerService(AutoRefreshingAuthClient client)
    : _aiplatformApi = AiplatformApi(client);

  @override
  Future<List<OrganizeFilesByMonthResponse>> organizeFilesByMonth(
    Iterable<CsvFile> csvFiles,
  ) async {
    final prompt =
        '''
      You are a file organization expert.
      Your task is to group a list of file IDs by month in 'yyyy-MM' format based on their names.
      List of csv files: ${csvFiles.map((file) => file.toJson())};
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
                  parts: [GoogleCloudAiplatformV1Part(text: prompt)],
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
                          type: 'STRING',
                          description: '파일 이름',
                        ),
                      ),
                    },
                  ),
                  default_: [],
                  example: [
                    {
                      'month': '2023-02',
                      'files': [
                        'card_statement_2023-02.csv',
                        'invoice_2023-02.csv',
                      ],
                    },
                    {
                      'month': '2023-01',
                      'files': ['card_statement_2023-01.csv'],
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
  Future<CsvFile> organizeLedger(CsvFile ledgerCsvFile) async {
    final categories = [
      '교통비',
      '문화',
      '생활/잡화',
      '커피/간식',
      '용돈',
      '식비',
      '외식',
      '장보기',
      '건강',
      '개발',
      '통신비',
      '여행',
      '세금',
    ];
    final columns = ['날짜', '카테고리', '금액', '가맹점'];
    final prompt =
        '''
      You are a financial expert.
      Your task is to reformat the CSV content according to the following rules:
      - Categorize the CSV file into one of the categories: $categories.
      - Result CSV file should have the following columns: $columns.
      - CSV content: ${ledgerCsvFile.csv}
      Please return the reformatted CSV content.
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
                  parts: [GoogleCloudAiplatformV1Part(text: prompt)],
                  role: 'user',
                ),
              ],
              generationConfig: GoogleCloudAiplatformV1GenerationConfig(
                responseMimeType: ContentType.json.mimeType,
                responseSchema: GoogleCloudAiplatformV1Schema(
                  type: 'STRING',
                  description: 'Categorized and Reformatted CSV content',
                  default_: '',
                  example: _exampleCsv,
                  format: endpoint,
                ),
              ),
            ),
            endpoint,
          );
    } catch (e) {
      throw Exception('Failed to generate content with Vertex AI: $e');
    }

    final csv =
        aiResponse.candidates?.firstOrNull?.content?.parts?.firstOrNull?.text ??
        '';

    if (csv.isEmpty) {
      throw Exception(
        'Received empty response from Vertex AI for file grouping.',
      );
    }

    return CsvFile(name: ledgerCsvFile.name, csv: csv);
  }
}

const _exampleCsv = '''
2025년 3월 1일,경기시내버스,"₩	8,400",교통비,-,전표접수,
2025년 3월 1일,티머니지하철,"₩	4,900",교통비,-,전표접수,
2025년 3월 1일,경기시내버스,"₩	80,400",교통비,-,전표접수,
2025년 3월 2일,Disney_Plus - Disney Plus,"₩	9,900",문화,-,전표접수,
2025년 3월 2일,네이버페이,"₩	25,784",생활/잡화,-,전표접수,
2025년 3월 2일,GS25이천오천점,"₩	14,290",커피/간식,-,전표접수,
2025년 3월 2일,경기시내버스,"₩	5,600",교통비,-,전표접수,
2025년 3월 3일,투썸플레이스이천마장점,"₩	1,000",커피/간식,-,전표접수,
2025년 3월 3일,쏘카 - ( 주 ) 쏘카,"₩	18,191",교통비,-,전표접수,
2025년 3월 3일,NICE_주차장 - 신세계,"₩	19,000",교통비,-,전표접수,
2025년 3월 3일,신세계사우스시티,"₩	2,300",커피/간식,-,전표접수,
2025년 3월 3일,쏘카 - ( 주 ) 쏘카,"₩	49,410",교통비,-,전표접수,
2025년 3월 4일,네이버페이,"₩	54,400",용돈,-,전표접수,
2025년 3월 4일,커피나인강남역,"₩	7,800",커피/간식,-,전표접수,
2025년 3월 5일,Apple - 엔에이치엔케이씨피(주),"₩	3,300",문화,-,전표접수,
2025년 3월 6일,최강어묵,"₩	10,000",식비,-,전표접수,
2025년 3월 7일,GS25이천오천점,"₩	22,730",커피/간식,-,전표접수,
2025년 3월 7일,커피나인강남역,"₩	5,800",커피/간식,-,전표접수,
2025년 3월 7일,바바인디아,"₩	21,000",식비,-,전표접수,
2025년 3월 8일,GS25이천오천점,"₩	22,400",커피/간식,-,전표접수,
2025년 3월 8일,이락해물칼국수마장2호점,"₩	24,000",식비,-,전표접수,
2025년 3월 10일,GS25서초여신점,"₩	2,050",커피/간식,-,전표접수,
2025년 3월 10일,동달식당강남본점,"₩	17,000",식비,-,전표접수,
2025년 3월 11일,AIRBNB * HMCHKN2ZWD,"₩	(136,957)",여행,-,취소전표접수,
2025년 3월 11일,삼성각,"₩	11,000",식비,-,전표접수,
2025년 3월 11일,"GITHUB, INC.","₩	146,540",개발,-,전표접수,
2025년 3월 12일,GS25이천오천점,"₩	21,430",커피/간식,-,전표접수,
2025년 3월 12일,GS25서초여신점,"₩	2,100",커피/간식,-,전표접수,
2025년 3월 12일,아비꼬,"₩	17,000",식비,-,전표접수,
2025년 3월 13일,GS25이천오천점,"₩	12,000",커피/간식,-,전표접수,
2025년 3월 13일,우아한형제들_애플페이 - (주)우아한형제들,"₩	31,900",외식,-,전표접수,
2025년 3월 13일,스폰티니강남점,"₩	17,900",식비,-,전표접수,
2025년 3월 14일,스폰티니강남점,"₩	14,900",식비,-,전표접수,
2025년 3월 14일,램커피,"₩	3,500",커피/간식,-,전표접수,
2025년 3월 15일,우리마트,"₩	12,800",장보기,-,전표접수,
2025년 3월 15일,영진올바스켓,"₩	13,380",장보기,-,전표접수,
2025년 3월 15일,씨유CU이천드리아드점,"₩	1,000",커피/간식,-,전표접수,
2025년 3월 17일,우아한형제들_애플페이 - (주)우아한형제들,"₩	31,800",외식,-,전표접수,
2025년 3월 17일,보승회관강남역서초점,"₩	12,500",식비,-,전표접수,
2025년 3월 18일,Apple - 엔에이치엔케이씨피(주),"₩	3,300",생활/잡화,-,전표접수,iCloud
2025년 3월 18일,Apple - 엔에이치엔케이씨피(주),"₩	14,900",문화,-,전표접수,Apple One
2025년 3월 18일,램커피,"₩	3,000",커피/간식,-,전표접수,
2025년 3월 18일,이태리부대찌개강남역점,"₩	11,000",식비,-,전표접수,
2025년 3월 19일,플러스엔약국,"₩	6,000",건강,-,전표접수,
2025년 3월 19일,GS25서초여신점,"₩	5,680",커피/간식,-,전표접수,
2025년 3월 19일,램커피,"₩	3,000",커피/간식,-,전표접수,
2025년 3월 19일,하노이의아침,"₩	14,000",식비,-,전표접수,
2025년 3월 19일,GS25이천오천점,"₩	15,770",커피/간식,-,전표접수,
2025년 3월 20일,영농마트,"₩	68,530",장보기,-,전표접수,
2025년 3월 20일,백소정강남역신분당선점,"₩	15,500",식비,-,전표접수,
2025년 3월 20일,KT통신요금자동납부,"₩	73,190",통신비,-,전표접수,
2025년 3월 21일,컴포즈커피이천마장점,"₩	6,300",커피/간식,-,전표접수,
2025년 3월 22일,GS25이천오천점,"₩	15,300",커피/간식,-,전표접수,
2025년 3월 22일,오초오늘의초밥이천점,"₩	40,000",외식,-,전표접수,
2025년 3월 23일,영농마트,"₩	12,800",장보기,-,전표접수,
2025년 3월 23일,영농마트,"₩	21,100",장보기,-,전표접수,
2025년 3월 23일,컴포즈커피이천마장점,"₩	13,200",커피/간식,-,전표접수,
2025년 3월 24일,GS25서초여신점,"₩	2,300",커피/간식,-,전표접수,
2025년 3월 24일,동달식당강남본점,"₩	12,000",식비,-,전표접수,
2025년 3월 25일,GS25서초여신점,"₩	2,080",커피/간식,-,전표접수,
2025년 3월 25일,씨유강남승리점,"₩	5,700",커피/간식,-,전표접수,
2025년 3월 25일,오한수우육면가강남삼성타운점,"₩	9,800",식비,-,전표접수,
2025년 3월 26일,한율막국수,"₩	19,000",식비,-,전표접수,
2025년 3월 27일,해피약국,"₩	4,000",건강,-,전표접수,
2025년 3월 28일,GS25강남역1호점,"₩	3,900",커피/간식,-,전표접수,
2025년 3월 28일,포도강남역점,"₩	35,300",용돈,-,전표접수,
2025년 3월 29일,숯불에닭이천드리아드점,"₩	56,000",외식,-,전표접수,
2025년 3월 29일,영농마트,"₩	11,210",장보기,-,전표접수,
2025년 3월 29일,초록나무치과의원,"₩	19,200",건강,-,전표접수,
2025년 3월 30일,네이버페이,"₩	53,498",커피/간식,-,전표접수,커피 구독
2025년 3월 31일,씨유CU이천리첸시빌점,"₩	66,440",커피/간식,-,전표접수,
2025년 3월 31일,마장열린약국,"₩	4,900",건강,-,전표접수,
2025년 3월 31일,백세본튼튼의원,"₩	141,100",건강,-,전표접수,
2025년 3월 31일,GS25이천오천점,"₩	17,450",커피/간식,-,전표접수,
''';
