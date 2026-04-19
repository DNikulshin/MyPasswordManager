Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

. "$PSScriptRoot\Vault.ps1"
. "$PSScriptRoot\HotkeyManager.ps1"
. "$PSScriptRoot\InputSimulator.ps1"
. "$PSScriptRoot\Gui.ps1"

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# Скрываем окно консоли (работает и при ручном запуске, и при автозагрузке)
Add-Type -Name ConsoleHelper -Namespace Win32 -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
'@
$consoleHandle = [Win32.ConsoleHelper]::GetConsoleWindow()
if ($consoleHandle -ne [IntPtr]::Zero) {
    # 0 = SW_HIDE
    [Win32.ConsoleHelper]::ShowWindow($consoleHandle, 0) | Out-Null
}

$mutex = New-Object System.Threading.Mutex($false, "MyPasswordManagerApp")
if (-not $mutex.WaitOne(0, $false)) {
    [System.Windows.Forms.MessageBox]::Show("Приложение уже запущено.", "Ошибка", "OK", "Error")
    exit
}

Write-Host "Запуск менеджера паролей..." -ForegroundColor Cyan

$loginSuccess = $false
do {
    Write-Host "Запрос мастер-пароля..."
    $masterPass = Show-LoginWindow
    if ($masterPass -eq "RESET") {
        # Удаляем хранилище
        $vaultPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) ".my_pm"
        if (Test-Path $vaultPath) {
            Remove-Item -Path $vaultPath -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "Хранилище удалено. Будет создано новое."
            [System.Windows.Forms.MessageBox]::Show(
                "Хранилище успешно удалено.`nТеперь вы можете задать новый мастер-пароль.",
                "Сброс выполнен", "OK", "Information")
        }
        # Возвращаемся в начало цикла для нового входа
        continue
    }
    if (-not $masterPass) {
        Write-Host "Вход отменён пользователем."
        exit
    }
    try {
        $script:Vault = [PasswordVault]::new($masterPass)
        if (-not $script:Vault.Validate()) {
            throw "Неверный мастер-пароль"
        }
        $services = $script:Vault.ListServices()
        Write-Host "Успешно. Найдено записей: $($services.Count)"
        $loginSuccess = $true
    } catch {
        Write-Host "Ошибка входа: $($_.Exception.Message)" -ForegroundColor Red
        [System.Windows.Forms.MessageBox]::Show(
            "Неверный мастер-пароль. Попробуйте снова.",
            "Ошибка входа", "OK", "Error")
    }
} while (-not $loginSuccess)

Write-Host "Хранилище инициализировано. Создание иконки в трее..."

$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$iconPath = Join-Path $PSScriptRoot "icon.ico"
if (Test-Path $iconPath) {
    $notifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($iconPath)
} else {
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Shield
}
$notifyIcon.Text = "Менеджер паролей"
$notifyIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
$menuOpen = $contextMenu.Items.Add("Открыть менеджер")
$menuSeparator = New-Object System.Windows.Forms.ToolStripSeparator
$contextMenu.Items.Add($menuSeparator)
$menuExit = $contextMenu.Items.Add("Выход")

$menuOpen.Add_Click({
    Show-MainWindow -Vault $script:Vault
})
$menuExit.Add_Click({
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    if ($hook) { $hook.Dispose() }
    [System.Windows.Forms.Application]::Exit()
})
$notifyIcon.ContextMenuStrip = $contextMenu

try {
    $hook = New-Object KeyboardHook
    $hook.RegisterHotkey([System.Windows.Forms.Keys]::P, $true, $true, $false)
    Write-Host "Горячая клавиша зарегистрирована."
} catch {
    Write-Host "Не удалось зарегистрировать горячую клавишу: $($_.Exception.Message)" -ForegroundColor Yellow
    [System.Windows.Forms.MessageBox]::Show(
        "Не удалось зарегистрировать горячую клавишу.`nФункция автозаполнения по горячей клавише будет недоступна.",
        "Предупреждение", "OK", "Warning")
    $hook = $null
}

if ($hook) {
    $hook.HotkeyPressed = {
        $services = $script:Vault.ListServices()
        if ($services.Count -eq 0) {
            [System.Windows.Forms.MessageBox]::Show("Нет сохранённых паролей.", "Информация", "OK", "Information")
            return
        }
        
        # Окно выбора сервиса
        $form = New-Object System.Windows.Forms.Form -Property @{
            Text = "Выберите сервис"
            Size = New-Object System.Drawing.Size(300, 250)
            StartPosition = "CenterScreen"
            TopMost = $true
            FormBorderStyle = "FixedDialog"
            MaximizeBox = $false
        }
        $listBox = New-Object System.Windows.Forms.ListBox -Property @{
            Location = New-Object System.Drawing.Point(10, 10)
            Size = New-Object System.Drawing.Size(260, 140)
        }
        $services | Sort-Object | ForEach-Object { $listBox.Items.Add($_) | Out-Null }
        
        $chkPasswordOnly = New-Object System.Windows.Forms.CheckBox -Property @{
            Text = "Вставить только пароль"
            Location = New-Object System.Drawing.Point(10, 160)
            AutoSize = $true
        }
        
        $btnOk = New-Object System.Windows.Forms.Button -Property @{
            Text = "OK"
            Location = New-Object System.Drawing.Point(100, 190)
            DialogResult = "OK"
        }
        $btnCancel = New-Object System.Windows.Forms.Button -Property @{
            Text = "Отмена"
            Location = New-Object System.Drawing.Point(180, 190)
            DialogResult = "Cancel"
        }
        $form.Controls.Add($listBox)
        $form.Controls.Add($chkPasswordOnly)
        $form.Controls.Add($btnOk)
        $form.Controls.Add($btnCancel)
        $form.AcceptButton = $btnOk
        $form.CancelButton = $btnCancel
        
        $listBox.Add_DoubleClick({
            $form.DialogResult = "OK"
            $form.Close()
        })
        
        if ($form.ShowDialog() -eq "OK" -and $listBox.SelectedItem) {
            $service = $listBox.SelectedItem.ToString()
            $entry = $script:Vault.GetEntry($service)
            if ($entry) {
                $login = $entry.Username
                $passPtr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($entry.Password)
                try {
                    $password = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($passPtr)
                    
                    Start-Sleep -Milliseconds 300
                    
                    if ($chkPasswordOnly.Checked) {
                        # Только пароль
                        [System.Windows.Forms.SendKeys]::SendWait($password)
                    } else {
                        # Логин + Tab + пароль
                        [System.Windows.Forms.SendKeys]::SendWait($login)
                        Start-Sleep -Milliseconds 50
                        [System.Windows.Forms.SendKeys]::SendWait("{TAB}")
                        Start-Sleep -Milliseconds 50
                        [System.Windows.Forms.SendKeys]::SendWait($password)
                    }
                } finally {
                    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($passPtr)
                }
            }
        }
        $form.Dispose()
    }
}

Write-Host "Запуск Application.Run() (ожидание сообщений)..."
[System.Windows.Forms.Application]::Run()

if ($hook) { $hook.Dispose() }
$mutex.ReleaseMutex()