variable "crownid" {
    type = string
    default = "test"
}

variable "location" {
    type = string
    default = "Eastus"
}

variable "timezone" {
    type = string
    default = "America/New_York"
}

variable "admin_username" {}

variable "admin_password" {}

locals {
    customer_vms = {
        "rdp_vm" = {
            name = "cds-${var.crownid}-rdp"
            size = "Standard_B1ms"
            storage_type = "Premium_LRS"
        }
        "app_vm" = {
            name = "cds-${var.crownid}-app"
            size = "Standard_B1ms"
            storage_type = "Standard_LRS"
        }
    }
}

locals {
    storage_accounts = {
        "data" ={
            name = "cds${var.crownid}data"
            replication_type = "GRS"
        }
        "datadiag" = {
            name = "cds${var.crownid}datadiag"
            replication_type = "LRS"
        }
    }
}