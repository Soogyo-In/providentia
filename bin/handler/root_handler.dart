import 'dart:io';

import 'package:shelf/shelf.dart';

Response rootHandler(Request req) {
  final welcome = '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Providentia</title>
  <style>
      body { font-family: sans-serif; margin: 20px; background-color: #f4f4f4; color: #333; }
      .container { background-color: #fff; padding: 20px; border-radius: 8px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
      h1 { color: #2c3e50; }
      h2 { color: #34495e; }
      ul { list-style-type: none; padding-left: 0; }
      li { margin-bottom: 10px; background-color: #ecf0f1; padding: 10px; border-radius: 4px; }
      strong { color: #2980b9; }
      hr { border: 0; height: 1px; background: #ddd; margin: 20px 0; }
      .footer { text-align: center; margin-top: 20px; font-style: italic; color: #7f8c8d; }
  </style>
</head>
<body>
  <div class="container">
      <h1>Providentia 💰</h1>
      <p>Providentia는 재무 데이터 정리를 위한 프로젝트입니다. 📊</p>
      
      <h2>🎯 주요 기능</h2>
      <ul>
          <li><strong>Google Drive 연동</strong>: Google Drive에 업로드된 재무 관련 파일을 참조하여 분석합니다. 📄➡️🔎</li>
          <li><strong>자동 분류</strong>: 사용자가 정의한 카테고리에 따라 재무 데이터를 자동으로 분류합니다. 🗂️</li>
          <li><strong>현금흐름 예측</strong>: 사용자가 설정한 목표 금액 및 시점에 도달하기 위한 예상 현금흐름을 제공합니다. 📈💸</li>
      </ul>
      
      <hr>
      
      <p class="footer">✨ 이 프로젝트를 통해 재무 관리를 더욱 효율적으로 할 수 있기를 바랍니다! ✨</p>
  </div>
</body>
</html>
''';
  return Response.ok(
    welcome,
    headers: {HttpHeaders.contentTypeHeader: ContentType.html.mimeType},
  );
}
