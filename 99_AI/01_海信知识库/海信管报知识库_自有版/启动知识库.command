#!/bin/bash
# 海信管报知识库 · 本地服务启动器（双击运行）
cd "$(dirname "$0")"

PORT=8000
# 若端口已被占用（服务已在跑），直接打开浏览器
if nc -z 127.0.0.1 $PORT 2>/dev/null; then
  echo "✅ 服务已在运行，直接打开浏览器..."
  open "http://127.0.0.1:$PORT/index.html"
  exit 0
fi

python3 -m http.server $PORT --bind 127.0.0.1 &
SERVER_PID=$!
sleep 1
open "http://127.0.0.1:$PORT/index.html"

echo ""
echo "✅ 知识库服务已启动: http://127.0.0.1:$PORT"
echo "   - 血缘知识库: http://127.0.0.1:$PORT/index.html"
echo "   - WS/Dataset 图谱: http://127.0.0.1:$PORT/ws-map.html"
echo ""
echo "⚠️ 使用期间请保持本窗口开着；用完后关闭本窗口（或按 Ctrl+C）即停止服务。"
wait $SERVER_PID
