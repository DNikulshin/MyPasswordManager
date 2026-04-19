$appName = "MyPasswordManager"
$vbsPath = Join-Path $PSScriptRoot "Launcher.vbs"
$ps1Path = Join-Path $PSScriptRoot "Main.ps1"

# Создаём VBS-лаунчер, если его нет
if (-not (Test-Path $vbsPath)) {
    $vbsContent = @"
CreateObject("Wscript.Shell").Run "powershell.exe -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -File `"$ps1Path`"", 0, False
"@
    Set-Content -Path $vbsPath -Value $vbsContent -Encoding ASCII
    Write-Host "Создан файл Launcher.vbs" -ForegroundColor Green
}

# Команда для автозагрузки (запуск VBS через wscript.exe)
$command = "wscript.exe `"$vbsPath`""
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

Set-ItemProperty -Path $regPath -Name $appName -Value $command -Force
Write-Host "Менеджер паролей добавлен в автозагрузку (через Launcher.vbs)." -ForegroundColor Green