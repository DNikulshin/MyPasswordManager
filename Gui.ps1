# Gui.ps1
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Windows.Forms

# --- Окно входа (Windows Forms) ---
function Show-LoginWindow {
    $form = New-Object System.Windows.Forms.Form -Property @{
        Text = "Вход в менеджер паролей"
        Size = New-Object System.Drawing.Size(350, 210)
        StartPosition = "CenterScreen"
        FormBorderStyle = "FixedDialog"
        MaximizeBox = $false
        TopMost = $true
    }
    $lblPass = New-Object System.Windows.Forms.Label -Property @{
        Text = "Введите мастер-пароль:"
        Location = New-Object System.Drawing.Point(20, 20)
        AutoSize = $true
    }
    $txtPass = New-Object System.Windows.Forms.TextBox -Property @{
        Location = New-Object System.Drawing.Point(20, 50)
        Size = New-Object System.Drawing.Size(280, 20)
        PasswordChar = '*'
    }
    $chkShowPass = New-Object System.Windows.Forms.CheckBox -Property @{
        Text = "Показать пароль"
        Location = New-Object System.Drawing.Point(20, 80)
        AutoSize = $true
    }
    $btnOk = New-Object System.Windows.Forms.Button -Property @{
        Text = "OK"
        Location = New-Object System.Drawing.Point(120, 115)
        DialogResult = "OK"
    }
    $btnCancel = New-Object System.Windows.Forms.Button -Property @{
        Text = "Отмена"
        Location = New-Object System.Drawing.Point(200, 115)
        DialogResult = "Cancel"
    }
    $lnkForgot = New-Object System.Windows.Forms.LinkLabel -Property @{
        Text = "Забыли пароль?"
        Location = New-Object System.Drawing.Point(20, 145)
        AutoSize = $true
    }

    $chkShowPass.Add_CheckedChanged({
        if ($chkShowPass.Checked) {
            $txtPass.PasswordChar = [char]0
            $txtPass.UseSystemPasswordChar = $false
        } else {
            $txtPass.PasswordChar = '*'
        }
        $txtPass.Refresh()
    })

    $btnOk.Add_Click({
        if ([string]::IsNullOrEmpty($txtPass.Text)) {
            [System.Windows.Forms.MessageBox]::Show("Мастер-пароль не может быть пустым.", "Ошибка", "OK", "Warning")
            $form.DialogResult = "None"
        }
    })

    $lnkForgot.Add_Click({
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Это удалит ВСЕ сохранённые пароли безвозвратно!`n`nВы уверены, что хотите сбросить хранилище и задать новый мастер-пароль?",
            "Сброс хранилища",
            "YesNo",
            "Warning"
        )
        if ($result -eq "Yes") {
            $form.Tag = "RESET"
            $form.DialogResult = "Cancel"
            $form.Close()
        }
    })

    $form.Controls.AddRange(@($lblPass, $txtPass, $chkShowPass, $btnOk, $btnCancel, $lnkForgot))
    $form.AcceptButton = $btnOk
    $form.CancelButton = $btnCancel

    if ($form.ShowDialog() -eq "OK") {
        $securePass = ConvertTo-SecureString $txtPass.Text -AsPlainText -Force
        return $securePass
    } elseif ($form.Tag -eq "RESET") {
        return "RESET"
    } else {
        return $null
    }
}

# --- Окно настроек горячей клавиши (Windows Forms) ---
function Show-SettingsWindow {
    param([hashtable]$CurrentConfig)

    $form = New-Object System.Windows.Forms.Form -Property @{
        Text = "Настройки горячей клавиши"
        Size = New-Object System.Drawing.Size(300, 200)
        StartPosition = "CenterParent"
        FormBorderStyle = "FixedDialog"
        MaximizeBox = $false
    }
    $lblMods = New-Object System.Windows.Forms.Label -Property @{
        Text = "Модификаторы:"
        Location = New-Object System.Drawing.Point(20, 20)
        AutoSize = $true
    }
    $chkCtrl = New-Object System.Windows.Forms.CheckBox -Property @{
        Text = "Ctrl"
        Location = New-Object System.Drawing.Point(20, 45)
        Checked = $CurrentConfig.HotkeyModifiers.Ctrl
        AutoSize = $true
    }
    $chkShift = New-Object System.Windows.Forms.CheckBox -Property @{
        Text = "Shift"
        Location = New-Object System.Drawing.Point(100, 45)
        Checked = $CurrentConfig.HotkeyModifiers.Shift
        AutoSize = $true
    }
    $chkAlt = New-Object System.Windows.Forms.CheckBox -Property @{
        Text = "Alt"
        Location = New-Object System.Drawing.Point(180, 45)
        Checked = $CurrentConfig.HotkeyModifiers.Alt
        AutoSize = $true
    }
    $lblKey = New-Object System.Windows.Forms.Label -Property @{
        Text = "Клавиша:"
        Location = New-Object System.Drawing.Point(20, 80)
        AutoSize = $true
    }
    $cboKey = New-Object System.Windows.Forms.ComboBox -Property @{
        Location = New-Object System.Drawing.Point(100, 78)
        Width = 100
        DropDownStyle = "DropDownList"
    }
    $keys = @('A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z',
              'D0','D1','D2','D3','D4','D5','D6','D7','D8','D9',
              'F1','F2','F3','F4','F5','F6','F7','F8','F9','F10','F11','F12')
    $keys | ForEach-Object { $cboKey.Items.Add($_) | Out-Null }
    $cboKey.SelectedItem = $CurrentConfig.HotkeyKey

    $btnOk = New-Object System.Windows.Forms.Button -Property @{
        Text = "OK"
        Location = New-Object System.Drawing.Point(80, 120)
        DialogResult = "OK"
    }
    $btnCancel = New-Object System.Windows.Forms.Button -Property @{
        Text = "Отмена"
        Location = New-Object System.Drawing.Point(160, 120)
        DialogResult = "Cancel"
    }
    $form.Controls.AddRange(@($lblMods, $chkCtrl, $chkShift, $chkAlt, $lblKey, $cboKey, $btnOk, $btnCancel))
    $form.AcceptButton = $btnOk
    $form.CancelButton = $btnCancel

    if ($form.ShowDialog() -eq "OK") {
        return @{
            HotkeyModifiers = @{
                Ctrl  = $chkCtrl.Checked
                Shift = $chkShift.Checked
                Alt   = $chkAlt.Checked
            }
            HotkeyKey = $cboKey.SelectedItem.ToString()
        }
    }
    return $null
}

# --- Главное окно управления паролями (WPF) ---
function Show-MainWindow {
	
     param($Vault, [scriptblock]$OnHotkeyChanged)

    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Менеджер паролей" Height="450" Width="650"
        WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <Button Name="AddButton" Content="Добавить" Width="80" Margin="0,0,5,0"/>
            <Button Name="DeleteButton" Content="Удалить" Width="80" Margin="0,0,5,0"/>
            <TextBox Name="SearchBox" Width="200" Margin="10,0,0,0"/>
            <TextBlock Text="🔍" VerticalAlignment="Center" Margin="5,0,0,0"/>
			<Button Name="SettingsButton" Content="⚙" Width="30" Margin="10,0,0,0" ToolTip="Настройки горячей клавиши"/>
        </StackPanel>

        <DataGrid Name="DataGrid" Grid.Row="1" AutoGenerateColumns="False"
                  IsReadOnly="True" SelectionMode="Single">
            <DataGrid.Columns>
                <DataGridTextColumn Header="Сервис" Binding="{Binding Service}" Width="*"/>
                <DataGridTextColumn Header="Логин" Binding="{Binding Username}" Width="*"/>
            </DataGrid.Columns>
        </DataGrid>

        <StatusBar Grid.Row="2">
            <StatusBarItem>
                <TextBlock Name="StatusText" Text="Готов"/>
            </StatusBarItem>
        </StatusBar>
    </Grid>
</Window>
"@
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)

    $dataGrid = $window.FindName("DataGrid")
    $searchBox = $window.FindName("SearchBox")
    $statusText = $window.FindName("StatusText")
    $addButton = $window.FindName("AddButton")
    $deleteButton = $window.FindName("DeleteButton")
	$settingsButton = $window.FindName("SettingsButton")
	$settingsButton.Add_Click({
		$currentConfig = [PasswordVault]::LoadConfig()
		$newConfig = Show-SettingsWindow -CurrentConfig $currentConfig
		if ($newConfig) {
			[PasswordVault]::SaveConfig($newConfig)
			if ($OnHotkeyChanged) {
				& $OnHotkeyChanged $newConfig
			}
			[System.Windows.Forms.MessageBox]::Show("Настройки сохранены. Новая горячая клавиша активирована.", "Успех", "OK", "Information")
		}
	})

    # Блок обновления таблицы
    $updateGrid = {
        $services = $Vault.ListServices()
        Write-Host "DEBUG: Обновление таблицы. Сервисы: $($services -join ', ')"
        $items = @()
        foreach ($s in $services) {
            $entry = $Vault.GetEntry($s)
            if ($entry) {
                $items += [PSCustomObject]@{
                    Service  = $s
                    Username = $entry.Username
                }
            }
        }
        $filter = $searchBox.Text
        if ($filter) {
            $items = @($items | Where-Object { $_.Service -like "*$filter*" -or $_.Username -like "*$filter*" })
        }
        $dataGrid.ItemsSource = @($items)
        $dataGrid.Items.Refresh()
        $statusText.Text = "Записей: $($items.Count)"
    }

    # Событие изменения текста поиска
    $searchBox.Add_TextChanged({
        & $updateGrid
    })

    # Добавление записи
    $addButton.Add_Click({
        $dialog = New-Object System.Windows.Forms.Form -Property @{
            Text = "Новая запись"
            Size = New-Object System.Drawing.Size(400, 240)
            StartPosition = "CenterParent"
            FormBorderStyle = "FixedDialog"
            MaximizeBox = $false
        }
        $lblService = New-Object System.Windows.Forms.Label -Property @{Text="Сервис:"; Location="20,20"; AutoSize=$true}
        $txtService = New-Object System.Windows.Forms.TextBox -Property @{Location="120,20"; Width=200}
        $lblUser = New-Object System.Windows.Forms.Label -Property @{Text="Логин:"; Location="20,60"; AutoSize=$true}
        $txtUser = New-Object System.Windows.Forms.TextBox -Property @{Location="120,60"; Width=200}
        $lblPass = New-Object System.Windows.Forms.Label -Property @{Text="Пароль:"; Location="20,100"; AutoSize=$true}
        $txtPass = New-Object System.Windows.Forms.TextBox -Property @{Location="120,100"; Width=200; UseSystemPasswordChar=$true}
        $chkShowPass = New-Object System.Windows.Forms.CheckBox -Property @{
            Text = "Показать пароль"
            Location = New-Object System.Drawing.Point(120, 130)
            AutoSize = $true
        }
        $btnOk = New-Object System.Windows.Forms.Button -Property @{Text="OK"; Location="120,165"; DialogResult="OK"}
        $btnCancel = New-Object System.Windows.Forms.Button -Property @{Text="Отмена"; Location="200,165"; DialogResult="Cancel"}

        $chkShowPass.Add_CheckedChanged({
            $txtPass.UseSystemPasswordChar = -not $chkShowPass.Checked
        })

        $dialog.Controls.AddRange(@($lblService, $txtService, $lblUser, $txtUser, $lblPass, $txtPass, $chkShowPass, $btnOk, $btnCancel))
        $dialog.AcceptButton = $btnOk
        $dialog.CancelButton = $btnCancel

        if ($dialog.ShowDialog() -eq "OK" -and $txtService.Text -and $txtPass.Text) {
            $securePass = ConvertTo-SecureString $txtPass.Text -AsPlainText -Force
            $Vault.SaveEntry($txtService.Text, $txtUser.Text, $securePass)
            & $updateGrid
        }
        $dialog.Dispose()
    })

    # Удаление записи с подтверждением
    $deleteButton.Add_Click({
        if ($dataGrid.SelectedItem -eq $null) {
            [System.Windows.Forms.MessageBox]::Show("Выберите запись для удаления.", "Информация", "OK", "Information")
            return
        }
        $selectedItem = $dataGrid.SelectedItem
        $service = $selectedItem.Service
        Write-Host "DEBUG GUI: Выбран сервис для удаления: $service"
        $result = [System.Windows.Forms.MessageBox]::Show(
            "Вы уверены, что хотите удалить запись '$service'?",
            "Подтверждение удаления",
            "YesNo",
            "Warning"
        )
        if ($result -eq "Yes") {
            Write-Host "DEBUG GUI: Подтверждено удаление '$service'"
            $Vault.RemoveEntry($service)
            & $updateGrid
        }
    })

    # Первоначальное заполнение
    & $updateGrid

    $window.ShowDialog() | Out-Null
}
