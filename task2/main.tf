terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  features {}

  skip_provider_registration = true

}

locals {
  resource_group = "akzhol-rg"
  location       = "eastus"

}


resource "azurerm_resource_group" "akzhol-rg" {
  name     = local.resource_group
  location = local.location
}

resource "azurerm_virtual_network" "app_network" {
  name                = "app-network"
  location            = local.location
  resource_group_name = azurerm_resource_group.akzhol-rg.name
  address_space       = ["10.0.0.0/16"]
  depends_on = [
    azurerm_resource_group.akzhol-rg
  ]
}


resource "azurerm_network_security_group" "app_nsg" {
  name                = "app-nsg"
  location            = azurerm_resource_group.akzhol-rg.location
  resource_group_name = azurerm_resource_group.akzhol-rg.name

  # We are creating a rule to allow traffic on port 80
  security_rule {
    name                       = "Allow_HTTP"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "example" {
  name                = "test"
  location            = azurerm_resource_group.akzhol-rg.location
  resource_group_name = azurerm_resource_group.akzhol-rg.name
  allocation_method   = "Static"
  domain_name_label   = azurerm_resource_group.akzhol-rg.name
  sku                 = "Standard"

  tags = {
    environment = "staging"
  }
}


resource "azurerm_subnet" "example" {
  name                 = "acctsub"
  resource_group_name  = azurerm_resource_group.akzhol-rg.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.2.0/24"]
}


resource "azurerm_lb" "example" {
  name                = "test"
  location            = azurerm_resource_group.akzhol-rg.location
  resource_group_name = azurerm_resource_group.akzhol-rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.example.id
  }
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "BackEndAddressPool"
}


resource "azurerm_lb_nat_pool" "lbnatpool" {
  resource_group_name            = azurerm_resource_group.akzhol-rg.name
  name                           = "ssh"
  loadbalancer_id                = azurerm_lb.example.id
  protocol                       = "Tcp"
  frontend_port_start            = 50000
  frontend_port_end              = 50119
  backend_port                   = 22
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_lb_probe" "example" {
  loadbalancer_id = azurerm_lb.example.id
  name            = "http-probe"
  protocol        = "Http"
  request_path    = "/" #sdFkdsgfkdjgoitjgiotgjiotrjgiotrjgiojtriogjrdtgijrtighjthijothjoi\shorjhpstrhjstihjsrio
  port            = 80
}



resource "azurerm_lb_rule" "lb-rule" {
  loadbalancer_id                = azurerm_lb.example.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  backend_port                   = 80
  frontend_port                  = 80
  probe_id                       = azurerm_lb_probe.example.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bpepool.id]
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_linux_virtual_machine_scale_set" "scale-set" {
  name                            = "akzhol-vmss"
  resource_group_name             = azurerm_resource_group.akzhol-rg.name
  location                        = azurerm_resource_group.akzhol-rg.location
  sku                             = "Standard_B1s"
  instances                       = 1
  admin_username                  = "akzhol"
  admin_password                  = "Akzhol@1234567"
  disable_password_authentication = false
  custom_data                     = filebase64("web.conf")

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }


  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }



  network_interface {
    name                      = "nic-akzhol"
    primary                   = true
    network_security_group_id = azurerm_network_security_group.app_nsg.id



    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.example.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
      load_balancer_inbound_nat_rules_ids    = [azurerm_lb_nat_pool.lbnatpool.id]

    }
  }
}


resource "azurerm_monitor_autoscale_setting" "autoscale" {
  name                = "myAutoscaleSetting"
  resource_group_name = azurerm_resource_group.akzhol-rg.name
  location            = azurerm_resource_group.akzhol-rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.scale-set.id


  profile {
    name = "defaultProfile"

    capacity {
      default = 1
      minimum = 1
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.scale-set.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
        metric_namespace   = "microsoft.compute/virtualmachinescalesets"
        dimensions {
          name     = "AppName"
          operator = "Equals"
          values   = ["App1"]
        }
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.scale-set.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }

  notification {
    email {
      send_to_subscription_administrator    = true
      send_to_subscription_co_administrator = true
      custom_emails                         = ["akzhol.suborov@gmail.com"]
    }
  }
}



resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.example.id
  network_security_group_id = azurerm_network_security_group.app_nsg.id
  depends_on = [
    azurerm_network_security_group.app_nsg
  ]
}