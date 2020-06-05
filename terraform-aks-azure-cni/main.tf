provider "azurerm" {
  # Whilst version is optional, we /strongly recommend/ using it to pin the version of the Provider being used
  version = "=2.0.0"
  features {}
}

resource "azurerm_resource_group" "aks_rg" {
  name     = "${var.prefix}-rg"
  location = "${var.location}"
}


data "azurerm_subnet" "existing_vnet_subnet" {
    name                 = "${var.subnet_name}"
    virtual_network_name = "${var.vnet_name}"
    resource_group_name  = "${var.network_rg}"
}

resource "azurerm_kubernetes_cluster" "aks_c" {
  name                = "${var.prefix}-cluster"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "${var.prefix}"
  node_resource_group = "${var.prefix}-nodes-rg"
  kubernetes_version  = "${var.kubernetes_version}"
  identity            {
    type = "SystemAssigned"
  }
  linux_profile {
    admin_username = "azureuser"
    ssh_key {
      key_data = "${var.ssh_key}"
    }
  }

  # Placeholder service_principal (and client_id and client_secret) must currently  be present 
  # even if using the SystemAssigned Identity
  service_principal {
    client_id     = "unused_but_required_placeholder"
    client_secret = "unused_but_required_placeholder"
  }
  provisioner "local-exec" {
    # Load credentials to local environment so subsequent kubectl commands can be run
    command = <<EOS
      az aks get-credentials --resource-group ${azurerm_resource_group.aks_rg.name} --name ${self.name} --overwrite-existing;
EOS
  }
  provisioner "local-exec" {
    # Load credentials to local environment so subsequent kubectl commands can be run
    when = create
    command = "kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml"
  }

  provisioner "local-exec" {
    # Load credentials to local environment so subsequent kubectl commands can be run
    when = create
    command = "kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/mic-exception.yaml"
  }

  provisioner "local-exec" {
    when = create
    command = "az aks update -n ${azurerm_kubernetes_cluster.aks_c.name} -g ${azurerm_resource_group.aks_rg.name} --attach-acr ${var.acr_id}"
  }



  network_profile  {
    network_plugin = "azure"
    service_cidr = "${var.service_cidr}"
    dns_service_ip = "${var.dns_service_ip}"
    docker_bridge_cidr = "${var.docker_bridge_cidr}"
    load_balancer_sku = "standard"
    
  }
  
  default_node_pool {
    name                  = "defaultpool"
    vm_size               = "${var.machine_type}"
    node_count            = var.default_node_pool_size
    vnet_subnet_id        = data.azurerm_subnet.existing_vnet_subnet.id
  }

  tags = {
    Environment = "Production"
  }
}

resource "azurerm_user_assigned_identity" "mi_identity" {
  resource_group_name = azurerm_kubernetes_cluster.aks_c.node_resource_group
  location            = azurerm_resource_group.aks_rg.location
  name = "${var.prefix}-ui"
}



data "azurerm_subscription" "current_sub" {
}

resource "azurerm_role_assignment" "rbac_assignment" {
  scope                = data.azurerm_subscription.current_sub.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.mi_identity.principal_id
}

resource "azurerm_role_assignment" "aks_rbac_assignment" {
  scope                = data.azurerm_subscription.current_sub.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks_c.identity[0].principal_id
}


