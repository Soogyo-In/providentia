import 'package:shelf_router/shelf_router.dart';
import 'handler/handler.dart';

final router = Router()
  ..get(Route.root.path, rootHandler)
  ..post(Route.googleDriveWatch.path, googleDriveWatchHandler);

enum Route {
  root('/'),
  googleDriveWatch('/google/drive/watch');

  const Route(this.path);

  final String path;
}
