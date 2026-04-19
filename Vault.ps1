# Vault.ps1 (с отладкой удаления)
using namespace System.Security.Cryptography
using namespace System.Text
using namespace System.Runtime.InteropServices

class PasswordVault {
    [string] $VaultPath
    [string] $VaultFile
    hidden [byte[]] $Key
    hidden [bool] $WarningShown = $false
    
    PasswordVault([SecureString]$masterPassword) {
        $userProfile = [Environment]::GetFolderPath('UserProfile')
        $this.VaultPath = Join-Path $userProfile ".my_pm"
        if (-not (Test-Path $this.VaultPath)) {
            New-Item -Path $this.VaultPath -ItemType Directory -Force | Out-Null
            Write-Host "DEBUG Vault: Создана папка $($this.VaultPath)"
        }
        $this.VaultFile = Join-Path $this.VaultPath "data.secure"
        
        $ptr = [Marshal]::SecureStringToBSTR($masterPassword)
        try {
            $plain = [Marshal]::PtrToStringBSTR($ptr)
            $sha = [SHA256]::Create()
            $this.Key = $sha.ComputeHash([Encoding]::UTF8.GetBytes($plain))
        } finally {
            [Marshal]::ZeroFreeBSTR($ptr)
        }
    }
    
    [bool] Validate() {
        try {
            if (-not (Test-Path $this.VaultFile)) {
                $testEntry = @{
                    Username = "__validation__"
                    Password = "valid" | ConvertTo-SecureString -AsPlainText -Force | ConvertFrom-SecureString -Key $this.Key
                }
                $hash = @{ "__validation__" = $testEntry }
                $this._SaveAll($hash)
                return $true
            } else {
                $entries = $this._LoadAll()
                if ($entries.ContainsKey("__validation__")) {
                    $enc = $entries["__validation__"].Password
                    $null = $enc | ConvertTo-SecureString -Key $this.Key
                    return $true
                } else {
                    return $true
                }
            }
        } catch {
            Write-Host "DEBUG Vault: Ошибка валидации: $($_.Exception.Message)"
            return $false
        }
    }
    
    [void] SaveEntry([string]$service, [string]$username, [SecureString]$password) {
        Write-Host "DEBUG Vault: Сохранение записи '$service'"
        $entries = $this._LoadAll()
        $entries[$service] = @{
            Username = $username
            Password = $password | ConvertFrom-SecureString -Key $this.Key
        }
        $this._SaveAll($entries)
    }
    
    [PSCustomObject] GetEntry([string]$service) {
        $entries = $this._LoadAll()
        if ($entries.ContainsKey($service)) {
            $secure = $entries[$service].Password | ConvertTo-SecureString -Key $this.Key
            return [PSCustomObject]@{
                Service  = $service
                Username = $entries[$service].Username
                Password = $secure
            }
        }
        return $null
    }
    
    [string[]] ListServices() {
        $entries = $this._LoadAll()
        $services = @($entries.Keys | Where-Object { $_ -ne "__validation__" })
        Write-Host "DEBUG Vault: ListServices возвращает: $($services -join ', ')"
        return $services
    }
    
    [void] RemoveEntry([string]$service) {
        Write-Host "DEBUG Vault: RemoveEntry вызван для '$service'"
        $entries = $this._LoadAll()
        Write-Host "DEBUG Vault: Ключи до удаления: $($entries.Keys -join ', ')"
        if ($entries.ContainsKey($service)) {
            $entries.Remove($service)
            Write-Host "DEBUG Vault: Ключ '$service' удалён. Оставшиеся ключи: $($entries.Keys -join ', ')"
            $this._SaveAll($entries)
            Write-Host "DEBUG Vault: Сохранение после удаления выполнено."
        } else {
            Write-Host "DEBUG Vault: Ключ '$service' не найден!"
        }
    }
    
    hidden [hashtable] _LoadAll() {
        if (Test-Path $this.VaultFile) {
            try {
                $json = Get-Content $this.VaultFile -Raw -Encoding UTF8 -ErrorAction Stop
                if (-not [string]::IsNullOrWhiteSpace($json)) {
                    $obj = $json | ConvertFrom-Json -ErrorAction Stop
                    $hash = @{}
                    $obj.PSObject.Properties | ForEach-Object {
                        $hash[$_.Name] = $_.Value
                    }
                    return $hash
                }
            } catch {
                Write-Host "DEBUG Vault: Ошибка загрузки: $($_.Exception.Message)"
                throw
            }
        }
        return @{}
    }
    
    hidden [void] _SaveAll([hashtable]$entries) {
        Write-Host "DEBUG Vault: Сохранение в файл. Количество записей: $($entries.Count)"
        $json = $entries | ConvertTo-Json -Compress
        $tmpFile = $this.VaultFile + ".tmp"
        Set-Content -Path $tmpFile -Value $json -Encoding UTF8 -Force -ErrorAction Stop
        Move-Item -Path $tmpFile -Destination $this.VaultFile -Force -ErrorAction Stop
        if (Test-Path $this.VaultFile) {
            (Get-Item $this.VaultFile).Attributes = "Hidden"
        }
        Write-Host "DEBUG Vault: Файл сохранён: $($this.VaultFile)"
    }
}