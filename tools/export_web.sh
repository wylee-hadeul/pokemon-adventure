#!/bin/bash
# 웹 빌드 + 캐시 무효화(.pck/.wasm 요청에 빌드 ID를 붙여 재방문자도 새 버전을 받게 함)
set -e
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --headless --path . --export-release "Web" docs/index.html
BUILD_ID="$(date +%Y%m%d%H%M%S)"
SNIPPET="<script>(function(){var v='${BUILD_ID}';var f=window.fetch;window.fetch=function(u,o){if(typeof u==='string'&&/\\.(pck|wasm)\$/.test(u)){u+='?v='+v;}return f.call(this,u,o);};})();</script>"
python3 - "$SNIPPET" <<'PY'
import sys
p = "docs/index.html"
s = open(p, encoding="utf-8").read()
s = s.replace("</head>", sys.argv[1] + "\n</head>", 1)
open(p, "w", encoding="utf-8").write(s)
PY
touch docs/.nojekyll docs/.gdignore
echo "exported build ${BUILD_ID}"
