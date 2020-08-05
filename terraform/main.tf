provider "azurerm" {
  # Whilst version is optional, we /strongly recommend/ using it to pin the version of the Provider being used
  version = "=2.0.0"
  features {}
}


resource "azurerm_resource_group" "aks_rg" {
  name     = "${var.prefix}-rg"
  location = "${var.location}"
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
  
  default_node_pool {
    name                  = "defaultpool"
    vm_size               = "${var.machine_type}"
    node_count            = var.default_node_pool_size
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

resource "azurerm_role_assignment" "cc_rbac_assignment" {
  scope                = data.azurerm_subscription.current_sub.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.mi_identity.principal_id
}

resource "azurerm_role_assignment" "aks_rbac_assignment_1" {
  scope                = data.azurerm_subscription.current_sub.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks_c.identity[0].principal_id
}

resource "azurerm_role_assignment" "aks_rbac_assignment_2" {
  scope                = azurerm_resource_group.aks_rg.id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks_c.identity[0].principal_id
  depends_on = [azurerm_role_assignment.aks_rbac_assignment_1]
}

resource "azurerm_role_assignment" "aks_rbac_assignment_3" {
  scope                = azurerm_resource_group.aks_rg.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.aks_c.identity[0].principal_id
  depends_on = [azurerm_role_assignment.aks_rbac_assignment_2]
}

# resource "azurerm_role_assignment" "aks_rbac_assignment_4" {
#   scope                = azurerm_kubernetes_cluster.aks_c.identity[0].id
#   role_definition_name = "Managed Identity Operator"
#   principal_id         = azurerm_kubernetes_cluster.aks_c.identity[0].principal_id
#   depends_on = [azurerm_role_assignment.aks_rbac_assignment_3]
# }

resource "azurerm_role_assignment" "aks_rbac_assignment_5" {
  scope                = azurerm_user_assigned_identity.mi_identity.id
  role_definition_name = "Managed Identity Operator"
  principal_id         = azurerm_kubernetes_cluster.aks_c.identity[0].principal_id
  # depends_on = [azurerm_role_assignment.aks_rbac_assignment_4]
  depends_on = [azurerm_role_assignment.aks_rbac_assignment_3]
}

resource "null_resource" "aks_post_create" {
  provisioner "local-exec" {    
    when = create
    command = <<EOS
    # Load credentials to local environment so subsequent kubectl commands can be run
    az aks get-credentials --resource-group ${azurerm_resource_group.aks_rg.name} --name ${azurerm_kubernetes_cluster.aks_c.name} --overwrite-existing
    # Enable [AAD Pod Identity](https://github.com/Azure/aad-pod-identity)
    kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
    kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/mic-exception.yaml
    EOS
  }

  provisioner "local-exec" {    
    # attach the ACR registry to the cluster to allow it to pull the container image
    when = create
    command = "az aks update -n ${azurerm_kubernetes_cluster.aks_c.name} -g ${azurerm_resource_group.aks_rg.name} --attach-acr ${var.acr_id}"
  }

  depends_on = [azurerm_role_assignment.cc_rbac_assignment, azurerm_role_assignment.aks_rbac_assignment_5]
}
