###########################
### Przygotowal: Dominik Warminski
###########################
## Blok Zmiennych
###########################

$logFilePath = "C:\AZ2\logfile.log"  
$maxLogSize = 5MB
$backupCount = 5

###########################
## Blok Funkcji
###########################

function Rotate-LogFile {
    if (Test-Path $logFilePath) {
        for ($i = $backupCount; $i -ge 1; $i--) {
            $src = "$logFilePath.$i"
            $dst = "$logFilePath." + ($i + 1)
            if (Test-Path $src) {
                Rename-Item -Path $src -NewName $dst
            }
        }
        Rename-Item -Path $logFilePath -NewName "$logFilePath.1"
    }
}

function Save-Logg {
    param (
        [string]$message
    )

    if (-not (Test-Path $logFilePath)) {
        New-Item -ItemType File -Path $logFilePath | Out-Null
    }

    if ((Get-Item $logFilePath).Length -ge $maxLogSize) {
        Rotate-LogFile
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp; $message" | Out-File -FilePath $logFilePath -Append
}

###########################
## Start Script
###########################

Save-Logg -message "This is a test log message."
Save-Logg -message "Another test log entry."
