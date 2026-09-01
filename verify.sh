#!/usr/bin/env bash
# 창 없이 롬을 부팅해 화면을 찍고, build/expected*.png 와 픽셀 단위로 견준다.
#
# C-BIOS 가 부팅 로고를 몇 초 보여 준 뒤에야 슬롯을 훑고 카트리지 INIT 을
# 부른다. 그래서 기다리는 시간을 8초 아래로 내리면 안 된다.
#
#   ./verify.sh         둘 다
#   ./verify.sh 16      16x16 만
#   ./verify.sh 8       8x8 만
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/tools.sh"
cd "$ROOT"

WAIT="${WAIT_SECONDS:-8}"
WHICH="${1:-all}"
./build.sh "$WHICH"

verify_one() {                      # $1 = 판(16|8)
    local tag=""; [ "$1" = 8 ] && tag=8
    local shot="$ROOT/build/screenshot$tag.png"
    rm -f "$shot"
    cat > "build/verify$tag.tcl" <<TCL
after time $WAIT {
    screenshot -raw "$shot"
    exit
}
TCL
    "$OPENMSX_HEADLESS" -machine "$MSX_MACHINE" \
        -cart "$ROOT/build/hangul$tag.rom" -script "$ROOT/build/verify$tag.tcl"
    [ -f "$shot" ] || { echo "화면을 못 찍었다. 에뮬레이터가 일찍 끝났나?" >&2; exit 1; }
    printf '%sx%s  %s\n  ' "$1" "$1" "$shot"
    python3 tools/compare.py "$shot" "$ROOT/build/expected$tag.png"
}

case "$WHICH" in
    16)  verify_one 16 ;;
    8)   verify_one 8 ;;
    all) verify_one 16; verify_one 8 ;;
esac
