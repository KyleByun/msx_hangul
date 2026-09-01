# 도구 위치. 다른 MSX 프로젝트와 함께 쓰려고 저장소 밖에 둔다.
# quest 프로젝트의 tools.ps1 과 같은 자리를 가리킨다.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_ROOT="${MSX_TOOLS_ROOT:-$(cd "$ROOT/.." && pwd)/tools}"

SJASMPLUS="$TOOLS_ROOT/sjasmplus/sjasmplus"
OPENMSX_HEADLESS="$TOOLS_ROOT/run-openmsx-headless"
OPENMSX_GUI="$TOOLS_ROOT/run-openmsx-gui"

# C-BIOS_MSX2 는 openMSX 에 딸려 오는 MSX2 표준 설정이다. 실기 롬이 필요 없다.
MSX_MACHINE="C-BIOS_MSX2"

for t in "$SJASMPLUS" "$OPENMSX_HEADLESS"; do
    [ -x "$t" ] || { echo "도구를 찾을 수 없다: $t" >&2; exit 1; }
done
