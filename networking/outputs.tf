output "rg" {
    value = azurerm_resource_group.rg.name
}

output "loc" {
    value = azurerm_resource_group.rg.location
}

output "vnet" {
    value = azurerm_virtual_network.vnet
}

output "subnet" {
    value = azurerm_subnet.subnets
}

output "list" {
    value = local.cidr_blocks
}