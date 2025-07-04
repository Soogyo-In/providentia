import '../../spreadsheet_converter.dart';

abstract interface class LedgerService {
  Future<List<(String name, String id, String mimeType)>> getSpreadSheets();

  Future<List<OrganizeFilesByMonthResponse>> organizeFilesByMonth(
    List<(String name, String id, String mimeType)> fileMetadata,
  );

  Future<Csv> exportFileToCsv(String fileId, String mimeType);
}

class OrganizeFilesByMonthResponse {
  final String month;
  final List<FileMetadata> files;

  OrganizeFilesByMonthResponse({required this.month, required this.files});

  factory OrganizeFilesByMonthResponse.fromJson(Map<String, dynamic> json) {
    return OrganizeFilesByMonthResponse(
      month: json['month'] as String,
      files: (json['files'] as List)
          .cast<Map<String, dynamic>>()
          .map(FileMetadata.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'month': month,
      'files': files.map((item) => item.toJson()).toList(),
    };
  }
}

class FileMetadata {
  final String id;
  final String mimeType;

  FileMetadata({required this.id, required this.mimeType});

  factory FileMetadata.fromJson(Map<String, dynamic> json) {
    return FileMetadata(
      id: json['id'] as String,
      mimeType: json['mimeType'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'mimeType': mimeType};
  }
}

class SummerizeCsvByMonthResponse {
  final String month;
  final String csv;

  SummerizeCsvByMonthResponse({required this.month, required this.csv});

  factory SummerizeCsvByMonthResponse.fromJson(Map<String, dynamic> json) {
    return SummerizeCsvByMonthResponse(
      month: json['month'] as String,
      csv: json['csv'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'month': month, 'csv': csv};
  }
}
