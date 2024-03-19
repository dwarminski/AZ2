$source = "C:\AZ2\process"
$destination = @{
"Katalog1" = "C:\AZ2\Katalog1" 
"Katalog2" = "C:\AZ2\Katalog2" 
"Katalog3" = "C:\AZ2\Katalog3"
}

 
$files = Get-ChildItem $source
 
foreach ($file in $files) {
    $fullFileName = $file.Name
    $newFileName = $fullFileName.Substring($fullFileName.IndexOf("_") + 1)
    $prefix = $fullFileName.Split('_')[0]
    if ($destination.ContainsKey($prefix)) {
        $destinationFolder = $destination[$prefix]
        Move-Item -Path $file.FullName -Destination (Join-Path -Path $destinationFolder -ChildPath $newFileName)
    }
}
