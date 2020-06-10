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

variable "machine_type" {
  description = "The Azure Machine Type for the AKS Node Pool"
  default = "Standard_D4s_v3"
}

variable "default_node_pool_size" {
  description = "The default number of VMs for the AKS Node Pool"
  default = 1
}


variable "location" {
  description = "The Azure Region in which to run CycleCloud"
  default = "westus2"
}

variable "kubernetes_version" {
    description = "The Kubernetes version to use for the cluster."
    default =  "1.16.9"
}
