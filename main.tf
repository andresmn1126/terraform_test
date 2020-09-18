provider "azurerm" {
    features {}
}

resource "azurerm_resource_group" "rg" {
    name = "Testing-RG"
    location = "eastus2"

    tags = {
        Environemt = "Managed by Terraform"
    }
}

# Creates the virtual network
resource "azurerm_virtual_network" "vnet" {
    name = "TestVnet"
    # [] represent a list
    address_space = ["10.0.0.0/16"]
    location = "eastus2"
    resource_group_name = azurerm_resource_group.rg.name
}

# Creates the virtual subnet for the VM
resource "azurerm_subnet" "subnet" {
    name = "TestSubnet"
    resource_group_name = azurerm_resource_group.rg.name
    virtual_network_name = azurerm_virtual_network.vnet.name
    address_prefixes = ["10.0.1.0/24"]
}

# Create 2 public IP
resource "azurerm_public_ip" "publicip" {
    name = "TestPIP${count.index}"
    location = "eastus2"
    resource_group_name = azurerm_resource_group.rg.name
    allocation_method = "Static"
    count = 2
}

# Create security group and rules

resource "azurerm_network_security_group" "nsg" {
    name = "TestSG"
    location = "eastus2"
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
    location = "eastus2"
    resource_group_name = azurerm_resource_group.rg.name
    count = 2
    ip_configuration {
        name = "vNIC${count.index}"
        subnet_id = azurerm_subnet.subnet.id
        private_ip_address_allocation = "dynamic"
        public_ip_address_id = azurerm_public_ip.publicip[count.index].id
    }
}