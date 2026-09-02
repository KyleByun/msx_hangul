#!/usr/bin/env bash
# 롬을 창으로 띄운다. 그래픽 데스크톱 세션에서 쓴다.
#   ./run.sh        16x16 판
#   ./run.sh 8      8x8 판
#   ./run.sh 12     12x12 판
#   ./run.sh d8     달무리 8x8 판
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/tools.sh"
cd "$ROOT"
WHICH="${1:-16}"; TAG=""; [ "$WHICH" != 16 ] && TAG="$WHICH"
ROM="hangul$TAG"; [ "$WHICH" = d8 ] && ROM=dalmoori8
./build.sh "$WHICH"
exec "$OPENMSX_GUI" -machine "$MSX_MACHINE" -cart "$ROOT/build/$ROM.rom"
