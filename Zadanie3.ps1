###########################
### Przygotowal: Dominik Warminski
###########################

###########################
## Blok Zmiennych
###########################
# Deklaracja zmiennych
param (
    [Parameter(Mandatory)][string] $resourceGroupName,
    [Parameter(Mandatory)][string] $location,
    [Parameter(Mandatory)][string] $vnetName,
    [Parameter(Mandatory)][string] $exportPath
      )

###########################
## Blok Funkcji
###########################
function Connect-Azure {
    try { 
        Connect-AzAccount
    }
    catch {
        Install-Module -Name Az -AllowClobber -Scope CurrentUser
        Connect-AzAccount
    }   
}

function Create-VNet {
    param (
        $resourceGroupName,
        $location,
        $vnetName
    )
    $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name 'default' -AddressPrefix '10.0.0.0/24'
    New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroupName -Location $location -AddressPrefix '10.0.0.0/16' -Subnet $subnetConfig
}

function Get-AzureRegions {
    Get-AzLocation | select DisplayName, Location, PairedRegion
}

function Export-ResourceInfo {
    Get-AzResource | Export-Csv -Path "$exportPath/AllResources.csv" -NoTypeInformation -Delimiter ';'
}

###########################
## Start Skryptu
###########################
# Krok 1: Polaczenie z Azure i tworzenie zasobow
Connect-Azure
New-AzResourceGroup -Name $resourceGroupName -Location $location
Create-VNet -resourceGroupName $resourceGroupName -location $location -vnetName $vnetName

# Krok 1a: Wypisanie i analiza regionow
$regions = Get-AzureRegions
$regions | Format-Table -AutoSize

# Krok 2: Eksport informacji o wszystkich obiektach w subskrypcji
Export-ResourceInfo
