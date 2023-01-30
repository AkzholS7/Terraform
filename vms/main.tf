resource "azurerm_network_interface" "main" {
  count = length(data.terraform_remote_state.vpc.outputs.list)
  name                = "nic${count.index}"
  location            = data.terraform_remote_state.vpc.outputs.loc
  resource_group_name = data.terraform_remote_state.vpc.outputs.rg

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = data.terraform_remote_state.vpc.outputs.subnet[count.index].id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_virtual_machine" "main" {
  count = length(data.terraform_remote_state.vpc.outputs.list)
  name                  = "vm-${count.index}"
  location              = data.terraform_remote_state.vpc.outputs.loc
  resource_group_name   = data.terraform_remote_state.vpc.outputs.rg
  network_interface_ids = [azurerm_network_interface.main[count.index].id]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "hostname"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
}