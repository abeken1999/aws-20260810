import json
import os
from http.server import HTTPServer, BaseHTTPRequestHandler

class SimpleAPIHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        # ALBからのヘルスチェック用パス、およびルートパスへの対応
        if self.path in ['/', '/health']:
            self.send_response(200)
            self.send_header('Content-type', 'application/json; charset=utf-8')
            self.end_headers()
            
            # レスポンスデータ（JSON）
            response_body = {
                "status": "ok",
                "message": "Hello World from AWS ECS Fargate!",
                "environment": os.getenv("APP_ENV", "development")
            }
            
            self.wfile.write(json.dumps(response_body).encode('utf-8'))
        else:
            # 存在しないパスへのアクセスは 404
            self.send_response(404)
            self.send_header('Content-type', 'application/json; charset=utf-8')
            self.end_headers()
            response_body = {"status": "error", "message": "Not Found"}
            self.wfile.write(json.dumps(response_body).encode('utf-8'))

if __name__ == '__main__':
    # 環境変数 PORT があればそれを使い、なければ 80 番を使用
    port = int(os.getenv("PORT", 80))
    server_address = ('', port)
    httpd = HTTPServer(server_address, SimpleAPIHandler)
    print(f"Server starting on port {port}...")
    httpd.serve_forever()
