#############################################################################
#                                  Variables                                #
#############################################################################
$SubscriptionId = 'f07a573b-5972-45d5-96ff-9ed6f2db1a58'
$rgName = 'rg-test'
$Location = "KoreaCentral"
$managedDiskName = 'os-disk-vm-web-01'
$newDiskName = "osdisk-powershell-copy-01"
$VnetName = "vnet-test"
$SubnetId = "/subscriptions/f07a573b-5972-45d5-96ff-9ed6f2db1a58/resourceGroups/rg-test/providers/Microsoft.Network/virtualNetworks/vnet-test/subnets/default"
$nicName = "nic-test"
$vmName = "vm-copy-test"
$galleryName = "cgbckim"
$galleryImageDefinitionName = "vmss-general-bckim"
$galleryImageVersionName = "0.0.4"
$vmssName = "vmss-copy-test"
$vmssSku = "Standard_D4as_v4"
$vmssNicName = "VMOBDCPWEB001-nic01"

$IsAcceleratedNetworkSupported = @{Name = 'IsAcceleratedNetworkSupported'; Value = 'True' }
$features = @($IsHibernateSupported, $IsAcceleratedNetworkSupported)

#############################################################################
#                               Set Subscription                            #
#############################################################################
Select-AzSubscription -SubscriptionId $SubscriptionId

#############################################################################
#                                  DISK Copy                                #
#############################################################################
$managedDisk = Get-AzDisk -ResourceGroupName $rgName -DiskName $managedDiskName
$diskConfig = New-AzDiskConfig -SourceResourceId $managedDisk.Id -Location $managedDisk.Location -CreateOption Copy 

New-AzDisk -Disk $diskConfig -DiskName $newDiskName -ResourceGroupName $rgName

$CopyDisk = Get-AzDisk -ResourceGroupName $rgName -Name $newDiskName

#############################################################################
#                                  VM Create                                #
#############################################################################
$Vnet = $(Get-AzVirtualNetwork -ResourceGroupName $rgName -Name $VnetName)

$VMConfig = New-AzVMConfig -VMName $vmName -VMSize "Standard_B1s"

$NIC = New-AzNetworkInterface -Name $nicName -ResourceGroupName $rgName `
    -Location $Location -SubnetId $SubnetId

Set-AzVMOSDisk -VM $VMConfig -Name $newDiskName -ManagedDiskId $CopyDisk.Id -CreateOption Attach -Linux
$VMConfig = Add-AzVMNetworkInterface -VM $VMConfig -Id $NIC.Id
$VM = New-AzVM -VM $VMConfig -ResourceGroupName $rgName -Location $Location

#############################################################################
#                              VM Image Capture                             #
#############################################################################
Stop-AzVM -ResourceGroupName $rgName -Name $vmName -Force
Set-AzVm -ResourceGroupName $rgName -Name $vmName -Generalized
$VM = Get-AzVM -Name $vmName -ResourceGroupName $rgName

#############################################################################
#                         Definition Version Upload                         #
#############################################################################
$galleryImageVersion = New-AzGalleryImageVersion -ResourceGroupName $rgName -GalleryName $galleryName `
    -GalleryImageDefinitionName $galleryImageDefinitionName `
    -Name $galleryImageVersionName -Location $Location `
    -SourceImageId $VM.Id

#############################################################################
#                       VM Image Config from Gallery                        #
#############################################################################
$gallery = Get-AzGallery -ResourceGroupName $rgName `
    -GalleryName $galleryName

$galleryImage = Get-AzGalleryImageDefinition `
    -ResourceGroupName $rgName `
    -GalleryName $galleryName `
    -GalleryImageDefinitionName $galleryImageDefinitionName

#############################################################################
#                                VMSS Create                                #
#############################################################################
$vmssIPConf = New-AzVmssIPConfig `
    -Name $vmssNicName -SubnetId $SubnetId

$vmssConf = New-AzVmssConfig `
    -Location $Location -SkuCapacity 2 -SkuName $vmssSku -UpgradePolicyMode "Manual"

$vmssConf = Add-AzVmssNetworkInterfaceConfiguration `
    -Name $nicName `
    -VirtualMachineScaleSet $vmssConf `
    -Primary $true `
    -IpConfiguration $vmssIPConf

Set-AzVmssStorageProfile `
    -VirtualMachineScaleSet $vmssConf `
    -OsDiskCaching "ReadWrite" `
    -OsDiskCreateOption "Attach" `
    -ManagedDisk "Premium_LRS" `
    -ImageReferenceId $galleryImageVersion.Id

New-AzVmss `
    -ResourceGroupName $rgName `
    -VMScaleSetName $vmssName `
    -VirtualMachineScaleSet $vmssConf

#############################################################################
#                                   VM Remove                               #
#############################################################################
Remove-AzVM -ResourceGroupName $rgName -Name $vmName -Force
Remove-AzDisk -ResourceGroupName $rgName -DiskName $newDiskName -Force
Remove-AzNetworkInterface -ResourceGroupName $rgName -Name $nicName -Force
