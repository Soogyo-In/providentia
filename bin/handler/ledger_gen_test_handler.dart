import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:googleapis/aiplatform/v1.dart';
import 'package:googleapis/drive/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:shelf/shelf.dart';

import '../environments.dart';
import '../service/ledger/default_ledger_service.dart';
import '../service/ledger/ledger_service.dart';
import '../service/ledger/ledger_service_performance.dart';

Future<Response> ledgerGenTestHandler(Request req) async {
  final AutoRefreshingAuthClient client;
  try {
    client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(json.decode(credentials)),
      [
        DriveApi.driveReadonlyScope,
        DriveApi.driveFileScope,
        AiplatformApi.cloudPlatformScope,
      ],
    );
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to initialize Google API client: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final driveApi = DriveApi(client);
  final about = await driveApi.about.get(
    $fields: 'storageQuota(usage,usageInDrive,usageInDriveTrash,limit)',
  );
  log('usage: ${about.storageQuota?.usage}');
  log('usageInDrive: ${about.storageQuota?.usageInDrive}');
  log('usageInDriveTrash: ${about.storageQuota?.usageInDriveTrash}');
  log('limit: ${about.storageQuota?.limit}');

  return Response.ok(
    'Google API client initialized successfully.',
    headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
  );

  final ledgerService = LedgerServicePerformance(DefaultLedgerService(client));

  final List<(String name, String id, String mimeType)> fileMetadata;
  try {
    fileMetadata = await ledgerService.getSpreadSheets();
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to fetch spreadsheets: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final List<OrganizeFilesByMonthResponse> organized;
  try {
    organized = await ledgerService.organizeFilesByMonth(fileMetadata);
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to organize files by month: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  // final csvDataByMonth = <String, List<Csv>>{};
  final csvDataByMonth = <String, List<String>>{};
  for (final monthData in organized) {
    final csvTexts = <String>[];

    for (final file in monthData.files) {
      log('Exporting file to CSV: ${file.id} (${file.mimeType})');
      final csv = await ledgerService.exportFileToCsv(file.id, file.mimeType);
      csvTexts.add(csv.toString());
    }

    csvDataByMonth[monthData.month] = csvTexts;
  }

  return Response.ok(
    jsonEncode(csvDataByMonth),
    headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
  );
}
