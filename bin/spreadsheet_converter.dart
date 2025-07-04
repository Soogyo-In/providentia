import 'dart:math';

class Csv {
  Csv({
    required this.rowsCount,
    required this.columnsCount,
    required this.cells,
  });

  final int rowsCount;
  final int columnsCount;
  final List<String> cells;

  @override
  String toString() =>
      cells.chunked(columnsCount).map((row) => row.join(',')).join('\n');
}

extension on List<String> {
  Iterable<List<String>> chunked(int size) sync* {
    for (var i = 0; i < length; i += size) {
      yield sublist(i, min(i + size, length));
    }
  }
}
