# Connect-AzAccount
# Select-AzSubscription -SubscriptionId f07a573b-5972-45d5-96ff-9ed6f2db1a58

$bckimResourcePath = "D:\Cloocus\AZ\Powershell\csvtest.csv"
$bckimResourceInfo = Import-Csv -Path $bckimResourcePath

$resourcegroup = $bckimResourceInfo | Where-Object { $_.kind -eq "resourcegroup" }
$vnets = $bckimResourceInfo | Where-Object { $_.kind -eq "vnet" }
$subnets = $bckimResourceInfo | Where-Object { $_.kind -eq "subnet" }
$nsgrules = $bckimResourceInfo | Where-Object { $_.kind -eq "nsgrule" }
$nsgs = $bckimResourceInfo | Where-Object { $_.kind -eq "nsg" }

######################## Resource Group ########################
New-AzResourceGroup -Name $resourcegroup.name -Location $resourcegroup.region

######################## NSG ########################
foreach ($nsg in $nsgs) {
    New-AzNetworkSecurityGroup `
        -Name $nsg.name `
        -ResourceGroupName $nsg.rg `
        -Location $nsg.region
}

foreach ($nsgrule in $nsgrules) {
    $nsg = Get-AzNetworkSecurityGroup `
        -Name $nsgrule.nsg `
        -ResourceGroupName $nsgrule.rg

    Add-AzNetworkSecurityRuleConfig `
        -Name $nsgrule.name `
        -Protocol $nsgrule.protocol `
        -Priority $nsgrule.priority `
        -SourceAddressPrefix $nsgrule.sourceip `
        -SourcePortRange $nsgrule.sourceport `
        -DestinationAddressPrefix $nsgrule.destinationip `
        -DestinationPortRange $nsgrule.destinationport.split(",") `
        -Access $nsgrule.access `
        -Direction $nsgrule.direction `
        -NetworkSecurityGroup $nsg `
    | Set-AzNetworkSecurityGroup
}

######################## VNet ########################
foreach ($vnet in $vnets) {
    New-AzVirtualNetwork `
        -Name $vnet.name `
        -Location $vnet.region `
        -ResourceGroupName $vnet.rg `
        -AddressPrefix $vnet.vnetIp
}

######################## Subnet ########################
foreach ($subnet in $subnets) {
    $vnetInfo = Get-AzVirtualNetwork -Name $subnet.tag -ResourceGroupName $subnet.rg
    $nsgInfo = Get-AzNetworkSecurityGroup -Name $subnet.nsg -ResourceGroupName $subnet.rg

    Add-AzVirtualNetworkSubnetConfig `
        -Name $subnet.name `
        -AddressPrefix $subnet.subnetIp `
        -VirtualNetwork $vnetInfo `
        -NetworkSecurityGroup $nsgInfo
    $vnetInfo | Set-AzVirtualNetwork
}


