provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "rg" {
    name = "Testing-RG"
    location = var.location

    tags = {
        Environemt = "Managed by Terraform"
    }
}

# Create storage accounts and image file share
resource "azurerm_storage_account" "sa" {
    for_each = local.storage_accounts

    name = each.value.name
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location
    account_tier = "Standard"
    account_replication_type = each.value.replication_type
}

resource "azurerm_storage_share" "share" {
    name = "cds${var.crownid}data"
    storage_account_name = azurerm_storage_account.sa["data"].name
    quota = 500
}

# Creates the virtual network
resource "azurerm_virtual_network" "vnet" {
    name = "${var.crownid}-VNET"
    # [] represent a list
    address_space = ["10.0.0.0/16"]
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name
}

# Creates the virtual subnet for the VM
resource "azurerm_subnet" "subnet" {
    name = "${var.crownid}-Subnet"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["10.0.1.0/24"]
}

# Create 2 public IP
resource "azurerm_public_ip" "publicip" {
    for_each = local.customer_vms

    name = "${each.value.name}-publicIP"
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name
    allocation_method = "Static"
}

# Create security group and rules

resource "azurerm_network_security_group" "nsg" {
    name = "${var.crownid}-NSG"
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name

    security_rule {
        name = "RDP"
        priority = 1001
        direction = "inbound"
        access = "allow"
        protocol = "tcp"
        source_port_range = "*"
        destination_port_range = 3389
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }
}
 
resource "azurerm_network_interface" "vnic" {
    for_each = local.customer_vms

    name = "${each.value.name}-nic"
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name
    ip_configuration {
        name = "${each.value.name}-nic"
        subnet_id = azurerm_subnet.subnet.id
        private_ip_address_allocation = "dynamic"
        public_ip_address_id = azurerm_public_ip.publicip[each.key].id
    }
}

#resource "azurerm_network_interface_security_group_association" "sga" {
#    network_interface_id   = azurerm_network_interface.vnic.*.id
#    network_security_group_id = azurerm_network_security_group.nsg.id
#}

resource "azurerm_windows_virtual_machine" "vms" {
    for_each = local.customer_vms

    name = each.value.name
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location
    size = each.value.size
    admin_username = var.admin_username
    admin_password = var.admin_password
    network_interface_ids = [
        azurerm_network_interface.vnic[each.key].id
    ]
    
    os_disk {
        caching = "ReadWrite"
        storage_account_type = each.value.storage_type
    }

    source_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2019-Datacenter"
        version   = "latest"
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.sa["datadiag"].primary_blob_endpoint
    }
}