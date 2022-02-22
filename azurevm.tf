# Configure the Microsoft Azure Provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
}

# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "myelkterraformgroup" {
    name     = "myElkResourceGroup"
    location = "eastus"

    tags = {
        environment = "ELK Terraform Demo"
    }
}

# Create virtual network
resource "azurerm_virtual_network" "myelkterraformnetwork" {
    name                = "myelkVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myelkterraformgroup.name

    tags = {
        environment = "ELK Terraform Demo"
    }
}

# Create subnet
resource "azurerm_subnet" "myelkterraformsubnet" {
    name                 = "myElkSubnet"
    resource_group_name  = azurerm_resource_group.myelkterraformgroup.name
    virtual_network_name = azurerm_virtual_network.myelkterraformnetwork.name
    address_prefixes       = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "myelkterraformpublicip" {
    name                         = "myElkPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.myelkterraformgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "ELK Terraform Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myelkterraformnsg" {
    name                = "myElkNetworkSecurityGroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.myelkterraformgroup.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "ELK Terraform Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "myelkterraformnic" {
    name                      = "myElkNIC"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.myelkterraformgroup.name

    ip_configuration {
        name                          = "myElkNicConfiguration"
        subnet_id                     = azurerm_subnet.myelkterraformsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.myelkterraformpublicip.id
    }

    tags = {
        environment = "ELK Terraform Demo"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "elkexample" {
    network_interface_id      = azurerm_network_interface.myelkterraformnic.id
    network_security_group_id = azurerm_network_security_group.myelkterraformnsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "elkRandomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.myelkterraformgroup.name
    }

    byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "myelkstorageaccount" {
    name                        = "diag${random_id.elkRandomId.hex}"
    resource_group_name         = azurerm_resource_group.myelkterraformgroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "ELK Terraform Demo"
    }
}

# Create (and display) an SSH key
resource "tls_private_key" "eklexample_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { 
    value = tls_private_key.elkexample_ssh.private_key_pem 
    sensitive = true
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "myelkterraformvm" {
    name                  = "myElkVM"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.myelkterraformgroup.name
    network_interface_ids = [azurerm_network_interface.myelkterraformnic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myElkOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "18.04-LTS"
        version   = "latest"
    }

    computer_name  = "myelkvm"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.elkexample_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.myelkstorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "ELK Terraform Demo"
    }
}