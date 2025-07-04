import 'dart:developer';

import '../../spreadsheet_converter.dart';
import 'ledger_service.dart';

class LedgerServicePerformance implements LedgerService {
  LedgerServicePerformance(this._ledgerService);

  final LedgerService _ledgerService;

  final _watch = Stopwatch();

  @override
  Future<List<(String name, String id, String mimeType)>>
  getSpreadSheets() async {
    _watch.start();
    final result = await _ledgerService.getSpreadSheets();
    _watch.stop();
    log('getSpreadSheets took ${_watch.elapsedMilliseconds} ms');
    _watch.reset();
    return result;
  }

  @override
  Future<List<OrganizeFilesByMonthResponse>> organizeFilesByMonth(
    List<(String name, String id, String mimeType)> fileMetadata,
  ) async {
    _watch.start();
    final result = await _ledgerService.organizeFilesByMonth(fileMetadata);
    _watch.stop();
    log('organizeFilesByMonth took ${_watch.elapsedMilliseconds} ms');
    _watch.reset();
    return result;
  }

  @override
  Future<Csv> exportFileToCsv(String fileId, String mimeType) async {
    _watch.start();
    final result = await _ledgerService.exportFileToCsv(fileId, mimeType);
    _watch.stop();
    log('exportFileToCsv took ${_watch.elapsedMilliseconds} ms');
    _watch.reset();
    return result;
  }
}
