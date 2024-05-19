########################### 
### Przygotowal: Dominik Warminski
########################### 

########################### 
## Blok Zmiennych 
########################### 

param (
    [Parameter(Mandatory=$true)][string] $indexNumber,
    [Parameter(Mandatory=$true)][string] $baseDir,
    [Parameter()][string] $region
)

if (-not $region) {
    $region = "North Europe"
}

$scriptDir = "$baseDir\$indexNumber"
$logDir = "$scriptDir\log"
$logFilePath = "$logDir\log.txt"
$dataFilePath = "$scriptDir\dane.txt"
$reportFilePath = "$scriptDir\raport.txt"

$resourceGroupName = "RG_$indexNumber"
$vmPrefix = "VM-$indexNumber"
$vmSize = "Standard_B2s"
$storageAccountName = "mystorageacctplwit$indexNumber"
$vnetName = "VNet-$indexNumber"
$subnetName = "Subnet-$indexNumber"
$nsgName = "$vmPrefix-nsg"
$tagName = "student"
$tagValue = $indexNumber
$tags = @{ $tagName = $tagValue }

########################### 
## Blok Funkcji
############################ 

# Logowanie do pliku
function Save-Log {
    param (
        [string]$message
    )

    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir | Out-Null
    }

    if (-not (Test-Path $logFilePath)) {
        New-Item -ItemType File -Path $logFilePath | Out-Null
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp; $message" | Out-File -FilePath $logFilePath -Append
}

# Obsługa błędów
function Handle-Error {
    param (
        [string]$errorMessage
    )
    Save-Log -message "ERROR: $errorMessage"
    Write-Error $errorMessage
    exit 1
}

# Tworzenie grupy zasobów
function Create-ResourceGroup {
    param (
        [string]$resourceGroupName,
        [string]$region,
        [hashtable]$tags
    )
    try {
        New-AzResourceGroup -Name $resourceGroupName -Location $region -Tag $tags -ErrorAction Stop
        Save-Log -message "Resource Group '$resourceGroupName' created."
    } catch {
        Handle-Error "Failed to create Resource Group."
    }
}

# Tworzenie wirtualnej sieci
function Create-VNet {
    param (
        [string]$resourceGroupName,
        [string]$region,
        [string]$vnetName,
        [string]$subnetName
    )
    try {
        $vnetParams = @{
            Name = $vnetName
            ResourceGroupName = $resourceGroupName
            Location = $region
            AddressPrefix = "10.0.0.0/16"
            Subnet = @{
                Name = $subnetName
                AddressPrefix = "10.0.1.0/24"
            }
        }
        $vnet = New-AzVirtualNetwork @vnetParams -ErrorAction Stop
        Save-Log -message "Virtual Network '$vnetName' created."

        # Dodawanie tagów do VNet
        Set-AzResource -ResourceId $vnet.Id -Tag $tags -ErrorAction Stop
        Save-Log -message "Tags added to Virtual Network '$vnetName'."
    } catch {
        Handle-Error "Failed to create Virtual Network. Error details: $_"
    }
}

# Tworzenie maszyny wirtualnej
function Create-VM {
    param (
        [string]$vmName,
        [string]$resourceGroupName,
        [string]$region,
        [string]$vmSize,
        [string]$vnetName,
        [string]$subnetName,
        [string]$nsgName,
        [hashtable]$tags
    )
    try {
        # Sprawdzenie dostępności rozmiaru VM
        $availableSizes = Get-AzVMSize -Location $region -ErrorAction Stop
        if ($availableSizes.Name -notcontains $vmSize) {
            $vmSize = $availableSizes | Sort-Object MemoryInMB | Select-Object -First 1 | Select-Object -ExpandProperty Name
            Save-Log -message "VM size 'Standard_B2s' not available. Using alternative size '$vmSize'."
        }

        # Tworzenie adresu IP
        $publicIp = New-AzPublicIpAddress -ResourceGroupName $resourceGroupName -Name "$vmName-pip" -Location $region -AllocationMethod Static -Sku Standard -ErrorAction Stop
        Save-Log -message "Public IP Address '$($publicIp.Name)' created."

        # Pobieranie informacji o podsieci
        $vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName -ErrorAction Stop
        $subnet = $vnet.Subnets | Where-Object { $_.Name -eq $subnetName }

        # Pobieranie informacji o NSG
        $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $resourceGroupName -Name $nsgName -ErrorAction Stop

        $nicParams = @{
            ResourceGroupName = $resourceGroupName
            Location = $region
            Name = "$vmName-nic"
            SubnetId = $subnet.Id
            PublicIpAddressId = $publicIp.Id
            NetworkSecurityGroupId = $nsg.Id
        }

        # Tworzenie karty sieciowej
        $nic = New-AzNetworkInterface @nicParams -ErrorAction Stop
        Save-Log -message "Network Interface '$($nic.Name)' created."

        # Parametry maszyny wirtualnej
        $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize | `
            Set-AzVMOperatingSystem -Windows -ComputerName $vmName -Credential (Get-Credential -Message "Enter VM credential") | `
            Set-AzVMSourceImage -PublisherName "MicrosoftWindowsServer" -Offer "WindowsServer" -Skus "2019-Datacenter" -Version "latest" | `
            Set-AzVMOSDisk -CreateOption FromImage -DiskSizeInGB 127 | `
            Add-AzVMNetworkInterface -Id $nic.Id

        # Tworzenie maszyny wirtualnej
        Save-Log -message "Creating VM with parameters: $($vmConfig | Out-String)"
        New-AzVM -ResourceGroupName $resourceGroupName -Location $region -VM $vmConfig -ErrorAction Stop
        Save-Log -message "VM '$vmName' created."

        # Pobranie ID maszyny wirtualnej
        $vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -ErrorAction Stop
        # Dodawanie tagów do VM
        Set-AzResource -ResourceId $vm.Id -Tag $tags -ErrorAction Stop
        Save-Log -message "Tags added to VM '$vmName'."
    } catch {
        Handle-Error "Failed to create VM '$vmName'. Error details: $_"
    }
}

# Tworzenie konta magazynu
function Create-StorageAccount {
    param (
        [string]$resourceGroupName,
        [string]$storageAccountName,
        [string]$region,
        [hashtable]$tags
    )
    try {
        $storageParams = @{
            ResourceGroupName = $resourceGroupName
            AccountName = $storageAccountName
            Location = $region
            SkuName = "Standard_LRS"
            Kind = "StorageV2"
            Tags = $tags
        }
        New-AzStorageAccount @storageParams -ErrorAction Stop
        Save-Log -message "Storage account '$storageAccountName' created."
    } catch {
        Handle-Error "Failed to create storage account. Error details: $_"
    }
}

# Tworzenie Network Security Group i konfiguracja reguł
function Create-NSG {
    param (
        [string]$resourceGroupName,
        [string]$region,
        [string]$vmPrefix,
        [hashtable]$tags
    )
    try {
        $nsgParams = @{
            ResourceGroupName = $resourceGroupName
            Location = $region
            Name = "$vmPrefix-nsg"
        }
        $nsg = New-AzNetworkSecurityGroup @nsgParams -ErrorAction Stop
        Save-Log -message "Network Security Group '$($nsg.Name)' created."

        # Dodawanie tagów do NSG
        Set-AzResource -ResourceId $nsg.Id -Tag $tags -ErrorAction Stop
        Save-Log -message "Tags added to Network Security Group '$($nsg.Name)'."

        # Tworzenie reguł NSG
        $rule80In = New-AzNetworkSecurityRuleConfig -Name "AllowInside-HTTP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80
        $rule80Out = New-AzNetworkSecurityRuleConfig -Name "AllowOutside-HTTP" -Access Allow -Protocol Tcp -Direction Outbound -Priority 100 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80
        $rule443In = New-AzNetworkSecurityRuleConfig -Name "AllowInside-HTTPS" -Access Allow -Protocol Tcp -Direction Inbound -Priority 200 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443
        $rule443Out = New-AzNetworkSecurityRuleConfig -Name "AllowOutside-HTTPS" -Access Allow -Protocol Tcp -Direction Outbound -Priority 200 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 443

        # Dodawanie reguł do NSG
        $nsg.SecurityRules.Add($rule80In)
        $nsg.SecurityRules.Add($rule80Out)
        $nsg.SecurityRules.Add($rule443In)
        $nsg.SecurityRules.Add($rule443Out)
        $nsg | Set-AzNetworkSecurityGroup -ErrorAction Stop

        Save-Log -message "NSG rules for ports 80 and 443 created."
    } catch {
        Handle-Error "Failed to create NSG or NSG rules. Error details: $_"
    }
}

# Generowanie raportu o zasobach w określonej grupie
function Generate-Report {
    param (
        [string]$resourceGroupName,
        [string]$reportFilePath
    )
    try {
        $resources = Get-AzResource -ResourceGroupName $resourceGroupName
        $reportContent = "Resource Group: $resourceGroupName`n"
        $reportContent += "Resources:`n"
        foreach ($resource in $resources) {
            $tagsKey = $resource.Tags.Keys
            $tagsValue = $resource.Tags.Values
            $reportContent += "Name: $($resource.Name), Type: $($resource.ResourceType), Tags: $tagsKey : $tagsValue`n"
        }
        $reportContent | Out-File -FilePath $reportFilePath -Encoding UTF8
        Save-Log -message "Report generated at '$reportFilePath'."
    } catch {
        Handle-Error "Failed to generate report. Error details: $_"
    }
}

# Usuwanie zasobów
function Clean-Up {
    param (
        [string]$resourceGroupName
    )
    try {
        Remove-AzResourceGroup -Name $resourceGroupName -Force -ErrorAction Stop
        Save-Log -message "Resource Group '$resourceGroupName' and all its resources have been removed."
    } catch {
        Handle-Error "Failed to clean up resources. Error details: $_"
    }
}

############################ 
## Start Script 
############################ 

Save-Log -message "Script started."

try { 
    Connect-AzAccount
}
catch {
    Install-Module -Name Az -Scope CurrentUser -AllowClobber
    Connect-AzAccount
}

# Tworzenie grupy zasobów
Create-ResourceGroup -resourceGroupName $resourceGroupName -region $region -tags $tags

# Tworzenie wirtualnej sieci
Create-VNet -resourceGroupName $resourceGroupName -region $region -vnetName $vnetName -subnetName $subnetName

# Tworzenie Network Security Group oraz reguł
Create-NSG -resourceGroupName $resourceGroupName -region $region -vmPrefix $vmPrefix -tags $tags

# Tworzenie maszyn wirtualnych z pliku
if (Test-Path $dataFilePath) {
    $vmNames = Get-Content -Path $dataFilePath
    foreach ($vmName in $vmNames) {
        Create-VM -vmName "$vmName$indexNumber" -resourceGroupName $resourceGroupName -region $region -vmSize $vmSize -vnetName $vnetName -subnetName $subnetName -nsgName $nsgName -tags $tags
    }
} else {
    Handle-Error "Data file '$dataFilePath' not found."
}

# Tworzenie konta magazynu
Create-StorageAccount -resourceGroupName $resourceGroupName -storageAccountName $storageAccountName -region $region -tags $tags

# Generowanie raportu nt. zasobów
Generate-Report -resourceGroupName $resourceGroupName -reportFilePath $reportFilePath

# Sprzątanie na koniec
Clean-Up -resourceGroupName $resourceGroupName

Save-Log -message "Script completed."
