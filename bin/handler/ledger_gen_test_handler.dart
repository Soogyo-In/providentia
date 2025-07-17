import 'dart:convert';
import 'dart:io';

import 'package:googleapis/aiplatform/v1.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:shelf/shelf.dart';

import '../environments.dart';
import '../service/ledger/default_ledger_service.dart';
import '../service/ledger/ledger_service.dart';
import '../service/ledger/ledger_service_decorators.dart';

Future<Response> ledgerGenTestHandler(Request req) async {
  final payload = jsonDecode(await req.readAsString()) as List;
  final csvList = payload
      .cast<Map<String, dynamic>>()
      .map(CsvFile.fromJson)
      .toList();

  final AutoRefreshingAuthClient client;
  try {
    client = await clientViaServiceAccount(
      ServiceAccountCredentials.fromJson(json.decode(credentials)),
      [AiplatformApi.cloudPlatformScope],
    );
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to initialize Google API client: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final ledgerService = DefaultLedgerService(client).performance().traced();

  final List<OrganizeFilesByMonthResponse> csvListByMonth;
  try {
    csvListByMonth = await ledgerService.organizeFilesByMonth(csvList);
  } catch (e) {
    return Response.internalServerError(
      body: 'Failed to organize files by month: $e',
      headers: {HttpHeaders.contentTypeHeader: ContentType.text.mimeType},
    );
  }

  final csvByFileName = {for (final file in csvList) file.name: file.csv};
  final mergedCsvList = csvListByMonth.map(
    (organized) => CsvFile(
      name: organized.month,
      csv: organized.fileNames
          .map((fileName) => csvByFileName[fileName])
          .join('\n\n'),
    ),
  );

  final organizedLedgers = <CsvFile>[];
  for (final csvFile in mergedCsvList) {
    organizedLedgers.add(await ledgerService.organizeLedger(csvFile));
  }

  return Response.ok(
    jsonEncode(organizedLedgers),
    headers: {HttpHeaders.contentTypeHeader: ContentType.json.mimeType},
  );
}
