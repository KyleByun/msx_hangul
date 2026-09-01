# 윈도우에서 쓸 때의 도구 위치. quest 프로젝트의 tools.ps1 과 같은 자리다.
# 리눅스에서는 tools.sh 를 쓴다.
$ToolsRoot   = "D:\my\8bit\msx\tools"
$SJASMPLUS   = Join-Path $ToolsRoot "sjasmplus\sjasmplus-1.23.1.win\sjasmplus.exe"
$OPENMSX     = Join-Path $ToolsRoot "openmsx\openmsx.exe"
$MSX_MACHINE = "C-BIOS_MSX2"

foreach ($t in @($SJASMPLUS, $OPENMSX)) {
    if (-not (Test-Path $t)) { throw "tool not found: $t" }
}
