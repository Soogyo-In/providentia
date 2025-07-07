import 'package:shelf/shelf.dart';

Response optOutHandler(Request request) {
  // 옵트아웃 페이지
  final String htmlContent = '''
      <!DOCTYPE html>
      <html>
      <head>
          <title>애드온 테스트 비활성화</title>
          <style>
              body { font-family: sans-serif; text-align: center; margin-top: 50px; }
              .container { max-width: 600px; margin: auto; padding: 20px; border: 1px solid #ccc; border-radius: 8px; }
              h1 { color: #333; }
              p { color: #555; }
              .button {
                  display: inline-block;
                  padding: 10px 20px;
                  background-color: #4285F4;
                  color: white;
                  text-decoration: none;
                  border-radius: 5px;
                  margin-top: 20px;
              }
          </style>
      </head>
      <body>
          <div class="container">
              <h1>providentia 테스트 비활성화</h1>
              <p>이 페이지는 워크스페이스 애드온 테스트를 비활성화하는 데 도움이 됩니다.</p>
              <p>애드온을 제거하려면 다음 단계를 따르세요:</p>
              <ol style="text-align: left; display: inline-block;">
                  <li>Google Workspace (Gmail, Calendar 등)에 로그인합니다.</li>
                  <li>애드온 사이드바에서 톱니바퀴 아이콘 또는 '애드온 관리' 옵션을 찾습니다.</li>
                  <li>"providentia 를 찾아 제거하거나 비활성화합니다.</li>
              </ol>
          </div>
      </body>
      </html>
    ''';
  return Response.ok(
    htmlContent,
    headers: {'Content-Type': 'text/html; charset=utf-8'},
  );
}
