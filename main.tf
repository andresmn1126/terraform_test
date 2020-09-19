provider "azurerm" {
    version = ">=2.0.0"
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
resource "azurerm_storage_account" "sadata" {
    name = "cds${crownid}data"
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location
    account_tier = "StandardV2"
    account_replication_type = "GRS"
}

resource "azure_storage_account" "sadiag" {
    name = "cds${crownid}datadiag"
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location
    account_tier = "StandardV2"
    account_replication_type = "LRS"
}

resource "azurerm_storage_share" "share" {
    name = "cds${crownid}data"
    azure_storage_account = azurerm_storage_account.sadata.name
    quote = 500
}

# Creates the virtual network
resource "azurerm_virtual_network" "vnet" {
    name = "${crownid}-VNET"
    # [] represent a list
    address_space = ["10.0.0.0/16"]
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name
}

# Creates the virtual subnet for the VM
resource "azurerm_subnet" "subnet" {
    name = "${crownid}-Subnet"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["10.0.1.0/24"]
}

# Create 2 public IP
resource "azurerm_public_ip" "publicip" {
    name = "${crownid}-IP-${count.index}"
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name
    allocation_method = "Static"
    count = 2
}

# Create security group and rules

resource "azurerm_network_security_group" "nsg" {
    name = "${crownid}-NSG"
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
    name = "NIC${count.index}"
    location = var.location
    resource_group_name = azurerm_resource_group.rg.name
    count = 2
    ip_configuration {
        name = "vNIC${count.index}"
        subnet_id = azurerm_subnet.subnet.id
        private_ip_address_allocation = "dynamic"
        public_ip_address_id = azurerm_public_ip.publicip[count.index].id
    }
}

resource "azurerm_network_interface_security_group_association" "sga" {
    network_interface_id   = azurerm_network_interface.vnic[*].index
    network_security_group = azurerm_network_security_group.nsg.id
}

resource "azurerm_windows_virtual_machine" "rdpvm" {
    name = "cds-${crownid}-rdp"
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location
    size = "Standard_D2s_v2"
    admin_username = var.admin_username
    admin_password = var.admin_password
    network_interface_ids = [
        azurerm_network_interface.vnic[0].id
    ]
    
    os_disk {
        caching = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2019-Datacenter"
        version   = "latest"
    }

# https://docs.microsoft.com/en-us/azure/developer/terraform/create-linux-virtual-machine-with-infrastructure
    boot_diagnostics {
        azurerm_storage_account = azurerm_storage_account.sadiag.primary_blob_endpoint
    }

}

resource "azurerm_windows_virtual_machine" "appvm" {
    name = "cds-${crownid}-app"
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location
    size = "Standard_D2s_v2"
    admin_username = var.admin_username
    admin_password = var.admin_password
    network_interface_ids = [
        azurerm_network_interface.vnic[0].id
    ]
    
    os_disk {
        caching = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer     = "WindowsServer"
        sku       = "2019-Datacenter"
        version   = "latest"
    }

    boot_diagnostics {
        azurerm_storage_account = azurerm_storage_account.sadiag.primary_blob_endpoint
    }

}