import 'package:shelf_router/shelf_router.dart';
import 'handler/handler.dart';

final router = Router()..get(Route.root.path, rootHandler);

enum Route {
  root('/');

  const Route(this.path);

  final String path;
}
