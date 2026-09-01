# 창 없이 롬을 부팅해 화면을 찍고 build/expected*.png 와 픽셀 단위로 견준다.
# C-BIOS 가 부팅 로고를 몇 초 보여 준 뒤에야 카트리지 INIT 을 부르므로
# $Seconds 를 8 아래로 내리면 안 된다.
param(
    [ValidateSet("all","16","8")] [string] $Which = "all",
    [double] $Seconds = 8
)
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\tools.ps1"

& "$PSScriptRoot\build.ps1" -Which $Which
if ($LASTEXITCODE -ne 0) { throw "build failed" }

function Verify-One([string] $Mode) {
    $tag  = if ($Mode -eq "8") { "8" } else { "" }
    $out  = "$PSScriptRoot\build\screenshot$tag.png"
    $tcl  = "$PSScriptRoot\build\verify$tag.tcl"

    # openMSX 는 Tcl 이라 역슬래시가 이스케이프다. 슬래시로 준다.
    $body = @"
after time $Seconds {
    screenshot -raw "$($out.Replace('\','/'))"
    exit
}
"@
    # BOM 이 있으면 Tcl 이 첫 명령의 일부로 읽어 파싱에 실패한다.
    [System.IO.File]::WriteAllText($tcl, $body, (New-Object System.Text.UTF8Encoding($false)))
    if (Test-Path $out) { Remove-Item $out }

    $proc = Start-Process -FilePath $OPENMSX -NoNewWindow -Wait -PassThru -ArgumentList @(
        '-machine', $MSX_MACHINE,
        '-cart',    "`"$PSScriptRoot\build\hangul$tag.rom`"",
        '-script',  "`"$tcl`""
    )
    if ($proc.ExitCode -ne 0) { throw "openMSX failed with exit code $($proc.ExitCode)" }
    if (-not (Test-Path $out)) { throw "no screenshot produced - the emulator exited early?" }

    Write-Host "${Mode}x${Mode}  $out"
    & python tools/compare.py $out "$PSScriptRoot\build\expected$tag.png"
    if ($LASTEXITCODE -ne 0) { throw "${Mode}x${Mode} 화면이 기대와 다르다" }
}

Push-Location $PSScriptRoot
try {
    if ($Which -eq "all" -or $Which -eq "16") { Verify-One "16" }
    if ($Which -eq "all" -or $Which -eq "8" ) { Verify-One "8"  }
}
finally { Pop-Location }
