terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.78.0"
    }
  }
}
provider "azurerm" {
  features {}
}


 resource "azurerm_resource_group" "rg1" {
   name     = "rg-terraform-az_09"
   location = "eastus"
   tags = {
 Owner= "Tarun"
 AutoDelete = "Yes"
 }
 }
