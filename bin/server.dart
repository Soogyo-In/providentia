import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';

import 'router.dart';

void main(List<String> args) async {
  final handler = Pipeline().addHandler(router.call);
  final address = InternetAddress.anyIPv4;
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  await serve(handler, address, port);
}
