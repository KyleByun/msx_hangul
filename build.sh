#!/usr/bin/env bash
# 롬 두 개를 만든다.
#
#   src/hangul.asm  -> build/hangul.rom   16x16 조합형 (벌 8/4/4)
#   src/hangul8.asm -> build/hangul8.rom  8x8 개미체   (벌 1/1/1)
#
# 어셈블 전에 tools/mkdata.py 를 돌려 폰트 바이너리와 화면 자료를 굽는다.
# 화면 정의가 mkdata.py 한 곳에만 있으므로, 롬과 build/expected*.png 가
# 어긋날 수 없다. verify.sh 가 둘을 픽셀 단위로 비교한다.
#
#   ./build.sh          둘 다
#   ./build.sh 16       16x16 만
#   ./build.sh 8        8x8 만
#   HANGUL_FONT=... / GAEMI_FONT=...   폰트 갈아 끼우기
set -euo pipefail

. "$(dirname "${BASH_SOURCE[0]}")/tools.sh"
cd "$ROOT"
mkdir -p build

build_one() {                       # $1 = 판(16|8), $2 = 폰트, $3 = 어셈블리
    local tag=""; [ "$1" = 8 ] && tag=8
    python3 tools/mkdata.py --mode "$1" ${2:+--font "$2"}
    "$SJASMPLUS" --msg=war --sym="build/hangul$tag.sym" --lst="build/hangul$tag.lst" "$3"
    printf 'built: build/hangul%s.rom (16384 bytes, 쓴 것 %s)\n' \
        "$tag" "$(grep -m1 '^HanFontEnd' "build/hangul$tag.sym" \
                  | sed 's/.*0x0*//' | python3 -c 'print(int(input(),16)-0x4000,"바이트")')"
}

case "${1:-all}" in
    16)  build_one 16 "${HANGUL_FONT:-}" src/hangul.asm ;;
    8)   build_one 8  "${GAEMI_FONT:-}"  src/hangul8.asm ;;
    all) build_one 16 "${HANGUL_FONT:-}" src/hangul.asm
         build_one 8  "${GAEMI_FONT:-}"  src/hangul8.asm ;;
    *)   echo "쓰임: $0 [16|8]" >&2; exit 1 ;;
esac
