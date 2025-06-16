import 'package:shelf_router/shelf_router.dart';
import 'handler/handler.dart';

final router = Router()
  ..get(Route.root.path, rootHandler)
  ..post(Route.watchGoogleDrive.path, googleDriveWatchHandler);

enum Route {
  root('/'),
  watchGoogleDrive('/google/drive/watch');

  const Route(this.path);

  final String path;
}
