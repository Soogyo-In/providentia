import 'dart:developer';

import 'ledger_service.dart';

extension LedgerServiceDecorator on LedgerService {
  LedgerService performance() => LedgerServicePerformance(this);
  LedgerService traced() => LedgerServiceTraced(this);
}

class LedgerServicePerformance implements LedgerService {
  LedgerServicePerformance(this._ledgerService);

  final LedgerService _ledgerService;
  final _watch = Stopwatch();

  @override
  Future<List<OrganizeFilesByMonthResponse>> organizeFilesByMonth(
    Iterable<CsvFile> csvFiles,
  ) async {
    _watch.start();
    final result = await _ledgerService.organizeFilesByMonth(csvFiles);
    _watch.stop();
    log(
      'Performance) organizeFilesByMonth took ${_watch.elapsedMilliseconds} ms',
    );
    _watch.reset();
    return result;
  }

  @override
  Future<CsvFile> organizeLedger(CsvFile ledgerCsvFile) async {
    _watch.start();
    final result = await _ledgerService.organizeLedger(ledgerCsvFile);
    _watch.stop();
    log('Performance) organizeLedger took ${_watch.elapsedMilliseconds} ms');
    _watch.reset();
    return result;
  }
}

class LedgerServiceTraced implements LedgerService {
  LedgerServiceTraced(this._ledgerService);

  final LedgerService _ledgerService;

  @override
  Future<List<OrganizeFilesByMonthResponse>> organizeFilesByMonth(
    Iterable<CsvFile> csvFiles,
  ) async {
    log('Tracing) organizeFilesByMonth with ${csvFiles.length} files');
    final result = await _ledgerService.organizeFilesByMonth(csvFiles);
    log('Tracing) organizeFilesByMonth result: ${result.map((e) => e.month)}');
    return result;
  }

  @override
  Future<CsvFile> organizeLedger(CsvFile ledgerCsvFile) async {
    log('Tracing) organizeLedger for file: ${ledgerCsvFile.name}');
    final result = await _ledgerService.organizeLedger(ledgerCsvFile);
    log('Tracing) organizeLedger result: ${result.name}');
    return result;
  }
}
