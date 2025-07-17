abstract interface class LedgerService {
  Future<List<OrganizeFilesByMonthResponse>> organizeFilesByMonth(
    Iterable<CsvFile> csvFiles,
  );

  Future<CsvFile> organizeLedger(CsvFile ledgerCsvFile);
}

class CsvFile {
  CsvFile({required this.name, required this.csv});

  final String name;
  final String csv;

  factory CsvFile.fromJson(Map<String, dynamic> json) {
    return CsvFile(name: json['name'] as String, csv: json['csv'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'csv': csv};
  }
}

class OrganizeFilesByMonthResponse {
  OrganizeFilesByMonthResponse({required this.month, required this.fileNames});

  final String month;
  final List<String> fileNames;

  factory OrganizeFilesByMonthResponse.fromJson(Map<String, dynamic> json) {
    return OrganizeFilesByMonthResponse(
      month: json['month'] as String,
      fileNames: (json['files'] as List).cast<String>(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'month': month, 'files': fileNames};
  }

  @override
  String toString() {
    return 'OrganizeFilesByMonthResponse(month: $month, fileNames: $fileNames)';
  }
}
