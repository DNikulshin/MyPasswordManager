# Uninstall.ps1 – удаление менеджера паролей
$ErrorActionPreference = "Stop"

$appName = "MyPasswordManager"
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "       Удаление менеджера паролей" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# 1. Удаление из автозагрузки
try {
    Remove-ItemProperty -Path $regPath -Name $appName -ErrorAction SilentlyContinue
    Write-Host "[OK] Запись удалена из автозагрузки." -ForegroundColor Green
} catch {
    Write-Host "[!] Не удалось удалить запись из автозагрузки: $($_.Exception.Message)" -ForegroundColor Yellow
}

# 2. Предложение удалить хранилище с паролями
$vaultPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) ".my_pm"
if (Test-Path $vaultPath) {
    $choice = Read-Host "Удалить зашифрованное хранилище паролей? (Y/N)"
    if ($choice -eq 'Y' -or $choice -eq 'y') {
        Remove-Item -Path $vaultPath -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[OK] Хранилище паролей удалено." -ForegroundColor Green
    } else {
        Write-Host "[i] Хранилище паролей оставлено по адресу: $vaultPath" -ForegroundColor Cyan
    }
} else {
    Write-Host "[i] Хранилище паролей не найдено." -ForegroundColor Gray
}

# 3. Удаление файлов программы (кроме самого Uninstall.ps1, если он лежит внутри)
$scriptPath = $PSScriptRoot
if ($scriptPath -and (Test-Path $scriptPath)) {
    $choice = Read-Host "Удалить все файлы программы в папке '$scriptPath'? (Y/N)"
    if ($choice -eq 'Y' -or $choice -eq 'y') {
        # Получаем список файлов, исключая текущий скрипт
        $files = Get-ChildItem -Path $scriptPath -Exclude "Uninstall.ps1"
        foreach ($f in $files) {
            Remove-Item -LiteralPath $f.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Host "[OK] Файлы программы удалены." -ForegroundColor Green
        
        # Пытаемся удалить саму папку (если пуста)
        if ((Get-ChildItem -Path $scriptPath).Count -eq 1 -and (Test-Path "$scriptPath\Uninstall.ps1")) {
            # Удаляем себя и папку (запустив внешнюю команду)
            $cmd = "cmd.exe /C timeout /t 1 /nobreak >nul & del /f /q `"$scriptPath\Uninstall.ps1`" & rmdir `"$scriptPath`""
            Start-Process -FilePath "cmd.exe" -ArgumentList "/C $cmd" -WindowStyle Hidden
            Write-Host "[OK] Папка программы будет удалена после завершения этого окна." -ForegroundColor Green
        } else {
            Write-Host "[i] Папка программы не пуста, удалите её вручную при необходимости." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[i] Файлы программы оставлены." -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "Удаление завершено." -ForegroundColor Cyan