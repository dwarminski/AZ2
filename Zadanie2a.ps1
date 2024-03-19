<#
.SYNOPSIS
Zbuduj processs przenoszenia zdjęć.
Pobierz z internetu zdjęcia z różnej tematyki.
Zdjęcia umieść 3 lub więcej katalogach zgodnie tematykom. - to będą nasze katalogi źródłowe
Przygotuj katalog processs.
Napisz skrypt, który pobierze zdjęcia z katalogów źródłowych i przeniesienie  do katalogu processs.
Napisz drugi skrypt, który przeniesie zdjęcia do właściwych dla siebie katalogów źródłowych.

.DESCRIPTION
Ograniczenia tego zadania:

Wszystkie katalogi tworzymy za pomocą komand powershell
Skrypty muszą być osobne i zapisane w plikach ps1
Wykorzystaj co najmniej 3 katalogi źródłowe (zdjęć może być po 2 na każdy katalog źródłowy)

#>

$source = @("C:\AZ2\Katalog1", "C:\AZ2\Katalog2", "C:\AZ2\Katalog3")
$destination = "C:\AZ2\process"
 
 
foreach ($folder in $source) {
    $files = Get-ChildItem $folder
    foreach ($file in $files) {
        $fileName = $file.Name
        $newFileName = $folder.Split('\')[-1] + "_" + $fileName
        Move-Item -Path $file.FullName -Destination (Join-Path -Path $destination -ChildPath $newFileName)
    }
}
