variable "prefix" {
  description = "The Prefix used for all CycleCloud VM resources"
  default = "cc-aks-tf"
}

variable "sp_client_id" {
  description = "Service Principle Client ID for AKS cluster (not used if using Managed Identity)"
  default="placeholder"
}

variable "sp_client_secret" {
  description = "Service Principle Client Secret for AKS cluster (not used if using Managed Identity)"
  default="placeholder"
}

variable "network_rg" {
  description = "Existing network resource group"
  default="your network rg name"
}

variable "vnet_name" {
  description = "Existing vnet name"
  default="your vnet name"
}
variable "subnet_name" {
  description = "Existing subnet name"
  default="your subnet name"
}

variable "machine_type" {
  description = "The Azure Machine Type for the AKS Node Pool"
  default = "Standard_D4s_v3"
}

variable "default_node_pool_size" {
  description = "The default number of VMs for the AKS Node Pool"
  default = 1
}

variable "service_cidr" {
  description = "Service CIDR"
  default = "10.211.0.0/16"
}
variable "dns_service_ip" {
  description = "dns_service_ip"
  default = "10.211.0.10"
}
variable "docker_bridge_cidr" {
  description = "Docker bridge CIDR"
  default = "172.17.0.1/16"
}

variable "acr_id" {
  description = "ACR Resource ID"
  default = "Your ACR Resource ID"
}

variable "location" {
  description = "The Azure Region in which to run CycleCloud"
  default = "eastus2"
}

variable "kubernetes_version" {
    description = "The Kubernetes version to use for the cluster."
    default =  "1.19.7"
}

variable "ssh_key" {
    description = "SSH Key"
    default = "place_holder"
}
