# Script settings
$relayServer = 'yourserver'
$apiKey = 'yourkey'
$tomlRustDesk2 = 'RustDesk2.toml'
$tomlRustDesk2Path = "$PSScriptRoot\$tomlRustDesk2"
$tomlRustDesk2DestPath = 'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\'
$rustDeskDataPath = 'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk'

# Function to get installed RustDesk version from registry
function Get-InstalledRustDeskVersion {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk"
    if (Test-Path $regPath) {
        return (Get-ItemProperty -Path $regPath -Name "Version").Version
    }
    return $null
}

# Function to get RustDesk uninstall command from registry
function Get-RustDeskUninstallCommand {
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\RustDesk"
    if (Test-Path $regPath) {
        return (Get-ItemProperty -Path $regPath -Name "UninstallString").UninstallString
    }
    return $null
}

# Fetch latest RustDesk version from GitHub
$apiUrl = "https://api.github.com/repos/rustdesk/rustdesk/releases/latest"
$response = Invoke-RestMethod -Uri $apiUrl -Headers @{Accept = "application/vnd.github.v3+json"}
$latestVersion = $response.name -replace "[^0-9.]", ''

# Get installed version
$installedVersion = Get-InstalledRustDeskVersion
Write-Host "Installed RustDesk version: $installedVersion"
Write-Host "Latest RustDesk version: $latestVersion"

# Compare versions and uninstall if outdated
if ($installedVersion -and ($installedVersion -lt $latestVersion)) {
    Write-Host "Older version detected. Uninstalling RustDesk..."
    $uninstallCmd = Get-RustDeskUninstallCommand
    if ($uninstallCmd) {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c $uninstallCmd /VERYSILENT /SUPPRESSMSGBOXES /NORESTART" -Wait
        
        # Remove RustDesk data directory
        if (Test-Path $rustDeskDataPath) {
            Write-Host "Removing RustDesk data directory..."
            Remove-Item -Path $rustDeskDataPath -Recurse -Force
        }
    } else {
        Write-Host "Uninstall command not found in registry. Skipping uninstallation."
    }
}

# Download and install the latest version if necessary
$exePath = "$PSScriptRoot\rustdesk-setup.exe"
if (-not $installedVersion -or $installedVersion -lt $latestVersion) {
    Write-Host "Downloading the latest RustDesk version..."
    $WinRelease = $response.assets | Where-Object { $_.name -like "*x86_64.exe" }
    Invoke-WebRequest -Uri $WinRelease.browser_download_url -OutFile $exePath
    
    Write-Host "Installing RustDesk..."
    Start-Process -FilePath $exePath -ArgumentList "--silent-install"
}

# Function to create RustDesk2.toml
function Create-ConfigFile {
    $configContent = @"
rendezvous_server = "$relayServer:21116"
[options]
custom-rendezvous-server = "$relayServer"
key = "$apiKey"
"@
    Set-Content -Path $tomlRustDesk2Path -Value $configContent
}

# RustDesk2.toml generation
Create-ConfigFile
Start-Sleep 15

# Copy RustDesk2.toml to destination
if (Test-Path $tomlRustDesk2Path) {
    Copy-Item -Path $tomlRustDesk2Path -Destination $tomlRustDesk2DestPath
} else {
    Write-Host "Warning: RustDesk2.toml not found!"
}

Restart-Service RustDesk
Write-Host "RustDesk installation and configuration complete with $relayServer!"
