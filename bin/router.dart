import 'package:shelf_router/shelf_router.dart';

import 'handler/handler.dart';
import 'handler/ledger_gen_test_handler.dart';

final router = Router()
  ..post('/ledger/gen/test', ledgerGenTestHandler)
  ..get(Route.root.path, rootHandler)
  ..post(Route.watchGoogleDrive.path, watchGoogleDriveHandler)
  ..post(
    Route.generateMonthlyLedgerFromDrive.path,
    generateMonthlyLedgerFromDriveHandler,
  );

enum Route {
  root('/'),
  watchGoogleDrive('/google/drive/watch'),
  generateMonthlyLedgerFromDrive('/google/drive/ledger/generate');

  const Route(this.path);

  final String path;

  Uri buildUrl(String baseUrl) {
    final uri = Uri.parse(baseUrl);
    return uri.replace(
      pathSegments: [
        ...uri.pathSegments,
        ...path.split('/').where((segment) => segment.isNotEmpty),
      ],
    );
  }
}
