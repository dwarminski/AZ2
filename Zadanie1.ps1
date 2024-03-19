<#
.SYNOPSIS
Wykorzystaj polecenie Get-Service do utworzenia pliku csv, (znak oddzielający poszczególne pola w pliku csv to „;”).

.DESCRIPTION
W tym plik umieść informację o:

Status Serwisu
Czy start serwisu jest opóźniony (w formie TAK-NIE)
Nazwa Serwisu
Jaki użytkownik uruchamia serwis
Jaki program jest uruchamiany przez serwis
Informację mają być zapisane dokładnie w tej kolejności jak podana wyżej.

.LINK
Uruchamiać tylko w wersji 5, wersja 7 zawiera błąd
https://github.com/PowerShell/PowerShell/issues/10371#issuecomment-1459112449


#>


$services = Get-Service | ForEach-Object {
    $serviceName = $_.DisplayName
    $service = Get-CimInstance -Class Win32_Service | Where-Object {$_.Name -eq $serviceName}

    $delayedStart = If ($service.StartMode -eq "Automatic" -and $service.State -ne "Running") {"TAK"} Else {"NIE"}

    [PSCustomObject]@{
        'Status' = $_.Status
        'Opozniony start?' = $delayedStart
        'Nazwa serwisu' = $serviceName
        'Uzytkownik' = $service.StartName
        'Wywolywany serwis' = $service.PathName
    }
}

$services | Export-Csv -Path "C:\AZ2\services_info.csv" -Delimiter ";" -NoTypeInformation -Encoding "utf8"

