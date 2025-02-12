# Script settings
$relayServer = 'yourserver'
$apiKey = 'yourkey'
$tomlRustDesk2 = 'RustDesk2.toml'
$tomlRustDesk2Path = "$env:temp\$tomlRustDesk2"
$tomlRustDesk2DestPath = 'C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\'

# RustDesk2.toml
function Create-ConfigFile {
    $configContent = @"
rendezvous_server = "$relayServer:21116"
[options]
custom-rendezvous-server = "$relayServer"
key = "$apiKey"
"@
    Set-Content -Path $tomlRustDesk2Path -Value $configContent
}

# Getting latest RustDesk version
Write-Host "Getting latest RustDesk version..."

$apiUrl = "https://api.github.com/repos/rustdesk/rustdesk/releases/latest"
$response = Invoke-RestMethod -Uri $apiUrl -Headers @{Accept = "application/vnd.github.v3+json"}

# Extract Windows installer URL (exe file)
$latestRelease = $response.assets | Where-Object { $_.name -like "*x86_64.exe" }
$downloadUrl = $latestRelease.browser_download_url

Write-Host "Latest version is: $($response.name)"
Write-Host "Downloading installer from: $downloadUrl"

# Download installer
$installerPath = "$env:temp\rustdesk-setup.exe"
Invoke-WebRequest -Uri $downloadUrl -OutFile $installerPath

# Silently install RustDesk with custom configuration
Write-Host "Installing RustDesk with custom configuration..."
#Start-Process -FilePath $installerPath -ArgumentList "--silent-install" -Wait
Start-Process -FilePath $installerPath -ArgumentList "--silent-install"

# RustDesk2.toml generation
Create-ConfigFile

Start-Sleep 15

# Copy RustDesk2.toml in C:\Windows\ServiceProfiles\LocalService\AppData\Roaming\RustDesk\config\
if (Test-Path $tomlRustDesk2Path) {
    Write-Host "Found $tomlRustDesk2 in script directory, copying to temp folder..."
    Copy-Item -Path $tomlRustDesk2Path -Destination $tomlRustDesk2DestPath
} else {
    Write-Host "Warning: $tomlRustDesk2 not found in script directory!"
}

Restart-Service RustDesk

Write-Host "RustDesk has been installed successfully and configured with $relayServer!"
