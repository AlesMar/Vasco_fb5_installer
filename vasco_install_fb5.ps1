# -----------------------
# Install-Firebird5.ps1
# -----------------------

$eventSource = "FirebirdInstaller"
$eventLog = "Application"

# Če Event Source še ne obstaja, ga ustvari
if (-not [System.Diagnostics.EventLog]::SourceExists($eventSource)) {
    New-EventLog -LogName $eventLog -Source $eventSource
}

function Write-Step {
    param (
        [string]$Message,
        [string]$Level = "Information"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "$timestamp [$Level] $Message"

    # Izpis na konzolo
    switch ($Level) {
        "Error"      { Write-Host $logLine -ForegroundColor Red }
        "Warning"    { Write-Host $logLine -ForegroundColor Yellow }
        default      { Write-Host $logLine -ForegroundColor Cyan }
    }

    # Zapis v Event Log
    $entryType = switch ($Level) {
        "Error"      { "Error" }
        "Warning"    { "Warning" }
        default      { "Information" }
    }
    Write-EventLog -LogName $eventLog -Source $eventSource -EntryType $entryType -EventId 1000 -Message $Message
}

# 1. Preverjanje administratorskih pravic
Write-Step "Preverjam administratorske pravice"
If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Step "Zaženite skripto kot skrbnik!" "Error"
    exit 1
}

# 2. Preverjanje, če je Firebird 5 klient že nameščen
Write-Step "Preverjam, ali je Firebird 5 klient že nameščen"
$clientPaths = @(
    "C:\Program Files\Firebird\Firebird_5_0\fbclient.dll"
)
$found = $false
foreach ($path in $clientPaths) {
    if (Test-Path $path) {
        Write-Step "Najdena komponenta klienta: $path"
        $found = $true
    }
}
if ($found) {
    Write-Step "Firebird 5 klient je že nameščen. Namestitev se prekine."
    exit 0
}

# 3. Brisanje starih DLL datotek (če obstajajo)
Write-Step "Brišem stare datoteke DLL"
$dllPaths = @("C:\Windows\System32\fbclient.dll", "C:\Windows\System32\gds32.dll")
foreach ($dll in $dllPaths) {
    if (Test-Path $dll) {
        Remove-Item $dll -Force
        Write-Step "Izbrisano: $dll"
    }
}

# 4. Prenašanje Firebird 5.0 installerja
Write-Step "Prenašam Firebird 5.0"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$installerUrl = "https://github.com/FirebirdSQL/firebird/releases/download/v5.0.2/Firebird-5.0.2.1613-0-windows-x64.exe"
$installerPath = "$env:TEMP\Firebird5.exe"
try {
    Invoke-WebRequest -Uri $installerUrl -OutFile $installerPath
    Write-Step "Prenos Firebird installerja uspešen."
} catch {
    Write-Step "Napaka pri prenosu Firebird installerja: $_" "Error"
    exit 1
}

# 5. Nameščanje Firebird 5.0
Write-Step "Nameščam Firebird 5.0"
try {
    Start-Process -FilePath $installerPath -ArgumentList "/SILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/FORCEINSTALL", `
      "/COMPONENTS=ClientComponent", `
      "/TASKS=UseServiceTask,AutoStartTask,CopyFbClientToSysTask,CopyFbClientAsGds32Task" -Wait
    Write-Step "Namestitev Firebird 5.0 uspešna."
} catch {
    Write-Step "Napaka med namestitvijo: $_" "Error"
    exit 1
}

Remove-Item $installerPath -Force

# 8. Zaključek
Write-Step "Inštalacija Firebird 5.0 dokončana."
