import 'package:shelf_router/shelf_router.dart';
import 'handler/handler.dart';

final router = Router()
  ..get(Route.root.path, rootHandler)
  ..get(Route.optOut.path, optOutHandler);
// ..post(Route.googleDriveWatch.path, googleDriveWatchHandler);

enum Route {
  root('/'),
  optOut('/opt-out'),
  googleDriveWatch('/google/drive/watch');

  const Route(this.path);

  final String path;
}
