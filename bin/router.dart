import 'package:shelf_router/shelf_router.dart';
import 'handler/handler.dart';

final router = Router()
  ..get(Route.root.path, rootHandler)
  ..post(Route.watchGoogleDrive.path, googleDriveWatchHandler);

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
