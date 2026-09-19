# LGS+ Windows — 開発起動 / リリースビルド
# 使い方（PowerShell）:
#   cd D:\LGS+windows
#   .\scripts\run_windows.ps1
#   .\scripts\run_windows.ps1 -Release

param(
    [switch]$Release
)

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "flutter が見つかりません。Flutter SDK を PATH に追加してください。https://docs.flutter.dev/get-started/install/windows"
}

Write-Host "==> flutter pub get"
flutter pub get

if ($Release) {
    Write-Host "==> flutter build windows --release"
    flutter build windows --release
    $exe = Join-Path (Get-Location) "build\windows\x64\runner\Release\LGSPlus.exe"
    Write-Host "完了: $exe"
    if (Test-Path $exe) {
        Start-Process explorer.exe "/select,$exe"
    }
} else {
    Write-Host "==> flutter run -d windows"
    flutter run -d windows
}
