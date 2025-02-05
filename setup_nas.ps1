# Установка Windows Admin Center
Write-Host "Installing Windows Admin Center..."
$wacInstaller = "https://aka.ms/WACDownload"
Invoke-WebRequest -Uri $wacInstaller -OutFile "$env:TEMP\WAC.msi"
Start-Process msiexec.exe -ArgumentList "/i $env:TEMP\WAC.msi /quiet /norestart" -Wait

# Проверка существования пользователя nasos
if (-Not (Get-LocalUser -Name "nasos" -ErrorAction SilentlyContinue)) {
    Write-Host "Creating user 'nasos'..."
    $Password = ConvertTo-SecureString "NasOS_123" -AsPlainText -Force
    New-LocalUser "nasos" -Password $Password -FullName "NAS User" -Description "NAS SMB User"
    Add-LocalGroupMember -Group "Users" -Member "nasos"
} else {
    Write-Host "User 'nasos' already exists, skipping creation."
}

# Настройка SMB и общего доступа
Write-Host "Setting up SMB share..."
$DownloadsPath = "$env:USERPROFILE\Downloads"
New-Item -Path $DownloadsPath -ItemType Directory -Force
icacls $DownloadsPath /grant "nasos:(OI)(CI)F" /T
New-SmbShare -Name "NAS" -Path $DownloadsPath -FullAccess "nasos" -ChangeAccess "Everyone" -ErrorAction SilentlyContinue

# Установка qBittorrent
Write-Host "Installing qBittorrent..."
$qbInstaller = "https://github.com/Starchik/install_nas/raw/refs/heads/main/qbittorrent.exe"
$qbPath = "$env:TEMP\qbittorrent.exe"
Invoke-WebRequest -Uri $qbInstaller -OutFile $qbPath

if (Test-Path $qbPath) {
    Start-Process -FilePath $qbPath -ArgumentList "/S" -Wait
} else {
    Write-Host "Failed to download qBittorrent, skipping installation."
}

# Настройка qBittorrent (включение веб-интерфейса)
Write-Host "Configuring qBittorrent..."
Start-Process -FilePath "$env:TEMP\qbittorrent.exe" -ArgumentList "/S" -Wait
Start-Sleep -Seconds 5
Stop-Process -Name "qbittorrent" -Force -ErrorAction SilentlyContinue

$qbConfigPath = "$env:APPDATA\qBittorrent\qBittorrent.ini"
if (Test-Path $qbConfigPath) {
    (Get-Content $qbConfigPath) -replace "WebUI\\Enabled=false", "WebUI\\Enabled=true" | Set-Content $qbConfigPath
    (Get-Content $qbConfigPath) -replace "Downloads\\SavePath=.*", "Downloads\\SavePath=$DownloadsPath" | Set-Content $qbConfigPath
} else {
    Write-Host "qBittorrent config file not found, skipping configuration."
}

Write-Host "NAS setup complete!"
