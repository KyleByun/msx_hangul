# 롬 두 개를 만든다. 리눅스에서는 ./build.sh 를 쓴다. 하는 일은 같다.
#   .\build.ps1          둘 다
#   .\build.ps1 -Which 16 / -Which 8
param(
    [ValidateSet("all","16","8")] [string] $Which     = "all",
    [string] $Font16 = "assets/hangul16.fnt",
    [string] $Font8  = "assets/gaemi7x8.fnt"
)
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\tools.ps1"

function Build-One([string] $Mode, [string] $Font, [string] $Asm) {
    $tag = if ($Mode -eq "8") { "8" } else { "" }
    # 화면 정의가 mkdata.py 한 곳에만 있다. 롬과 기대 그림을 함께 굽는다.
    & python tools/mkdata.py --mode $Mode --font $Font
    if ($LASTEXITCODE -ne 0) { throw "mkdata.py failed ($Mode)" }

    & $SJASMPLUS --msg=war --sym="build/hangul$tag.sym" --lst="build/hangul$tag.lst" $Asm
    if ($LASTEXITCODE -ne 0) { throw "sjasmplus failed on $Asm" }

    $size = (Get-Item "$PSScriptRoot\build\hangul$tag.rom").Length
    Write-Host "built: build/hangul$tag.rom ($size bytes)"
}

Push-Location $PSScriptRoot
try {
    New-Item -ItemType Directory -Force "$PSScriptRoot\build" | Out-Null
    if ($Which -eq "all" -or $Which -eq "16") { Build-One "16" $Font16 "src/hangul.asm" }
    if ($Which -eq "all" -or $Which -eq "8" ) { Build-One "8"  $Font8  "src/hangul8.asm" }
}
finally { Pop-Location }
