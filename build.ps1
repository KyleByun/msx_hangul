# 롬 네 개를 만든다. 리눅스에서는 ./build.sh 를 쓴다. 하는 일은 같다.
#   .\build.ps1          넷 다
#   .\build.ps1 -Which 16 / -Which 12 / -Which d8 / -Which 8
param(
    [ValidateSet("all","16","12","d8","8")] [string] $Which = "all",
    [string] $Font16 = "assets/hangul16.fnt",
    [string] $Font12 = "assets/saemmul12",
    [string] $FontD8 = "assets/dalmoori",
    [string] $Font8  = "assets/gaemi7x8.fnt"
)
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\tools.ps1"

function Build-One([string] $Mode, [string] $Font, [string] $Asm) {
    $rom = [System.IO.Path]::GetFileNameWithoutExtension($Asm)   # src/xxx.asm -> build/xxx.rom
    # 화면 정의가 mkdata.py 한 곳에만 있다. 롬과 기대 그림을 함께 굽는다.
    & python tools/mkdata.py --mode $Mode --font $Font
    if ($LASTEXITCODE -ne 0) { throw "mkdata.py failed ($Mode)" }

    & $SJASMPLUS --msg=war --sym="build/$rom.sym" --lst="build/$rom.lst" $Asm
    if ($LASTEXITCODE -ne 0) { throw "sjasmplus failed on $Asm" }

    $size = (Get-Item "$PSScriptRoot\build\$rom.rom").Length
    Write-Host "built: build/$rom.rom ($size bytes)"
}

Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force "$PSScriptRoot\build" | Out-Null
    if ($Which -eq "all" -or $Which -eq "16") { Build-One "16" $Font16 "src/hangul.asm" }
    if ($Which -eq "all" -or $Which -eq "12") { Build-One "12" $Font12 "src/hangul12.asm" }
    if ($Which -eq "all" -or $Which -eq "d8") { Build-One "d8" $FontD8 "src/dalmoori8.asm" }
    if ($Which -eq "all" -or $Which -eq "8" ) { Build-One "8"  $Font8  "src/hangul8.asm" }
}
finally { Pop-Location }
