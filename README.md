# AzureCycleAKSDeployment

Deploy Azure CycleCloud in a new [Azure Kubernetes](https://docs.microsoft.com/en-us/azure/aks/) cluster using the [AzureRM Terraform Provider](https://www.terraform.io/docs/providers/azurerm/r/kubernetes_cluster.html) and storing the container images in an [Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/).


For this  README, we'll use  the name 'cccontainerreguswest2' for the ACR registry and use the "West US 2" region in Azure.

## Pre-Requisites

* Install the Azure CLI
* Install Docker and Terraform
* Prepare a new [Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/) to store the CycleCloud container images.


## Build and push the Azure Cyclecloud Container Image

Log in to the Azure CLI
``` bash
az login
```

Create the Container Registry
``` bash
az group create --name cccontainerreg-rg --location westus2
az acr create --resource-group cccontainerreg-rg --name cccontainerreguswest2 --sku Premium
```

Build and Deploy container to ACR
``` bash
cd docker
az acr login -n cccontainerreguswest2
docker build -t cccontainerreguswest2.azurecr.io/cyclecloud:latest .
docker push cccontainerreguswest2.azurecr.io/cyclecloud
```

## Deploy the AKS cluster

Next, deploy the AKS cluster using Terraform.  (Alternatively, you may create the AKS cluster manually via the Portal  or Azure CLI.)

Ensure that the cluster is deployed to the same  region as the ACR registry when prompted.

```bash
cd terraform
terraform apply

```

## Assign the Roles to the Cluster's Managed Identity

Once the AKS cluster is deployed, the System Assigned Managed Identity for the AKS cluster and the User Assigned Managed Identity for the CycleCloud Pod must be permissioned.

> [!IMPORTANT]
> These instructions are based on the [AAD Pod Identity](https://github.com/Azure/aad-pod-identity) and may be out of date.  Refer to source for the most up-to-date instructions.

First, permission the AKS Cluster's system-assigned identity following the instructions in [AAD Pod Identity Pre-requisites](https://github.com/Azure/aad-pod-identity/blob/master/docs/readmes/README.msi.md#pre-requisites---role-assignments) documentation.
```bash
SUBSCRIPTION_ID=$( az account show --query id -o tsv )
AGENT_POOL_CLIENT_ID=$( az aks show -g cc-aks-tf-rg -n cc-aks-tf --query identityProfile.kubeletidentity.clientId -o tsv )

az role assignment create --role "Virtual Machine Contributor" --assignee ${AGENT_POOL_CLIENT_ID} --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/cc-aks-tf-nodes-rg
az role assignment create --role "Managed Identity Operator" --assignee ${AGENT_POOL_CLIENT_ID}  --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/cc-aks-tf-nodes-rg
az role assignment create --role "Managed Identity Operator" --assignee ${AGENT_POOL_CLIENT_ID}  --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/cc-aks-tf-nodes-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/cc-aks-tf-agentpool
az role assignment create --role "Managed Identity Operator" --assignee ${AGENT_POOL_CLIENT_ID}  --scope /subscriptions/${SUBSCRIPTION_ID}/resourceGroups/cc-aks-tf-nodes-rg/providers/Microsoft.ManagedIdentity/userAssignedIdentities/cc-aks-tf-ui

```

Get the AKS Credentials for the new cluster
```bash
az aks get-credentials --resource-group cc-aks-tf-rg  --name cc-aks-tf
```

After the terraform cluster is up, we still need to enable [AAD Pod Identity](https://github.com/Azure/aad-pod-identity):
```bash
kubectl apply -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml
```

Next, attach the ACR registry to the cluster to allow it to pull the container image:
```bash
az aks update --attach-acr cccontainerreguswest2 --resource-group cc-aks-tf-rg  --name cc-aks-tf
```

Now permission the CycleCloud User-Assigned Managed Identity:
```bash
SUBSCRIPTION_ID=$( az account show --query id -o tsv )
CLIENT_ID=$( az identity show --resource-group cc-aks-tf-nodes-rg --name cc-aks-tf-ui --query clientId -o tsv )

az role assignment create --assignee ${CLIENT_ID} --role=Contributor --scope=/subscriptions/${SUBSCRIPTION_ID}
```

Finally, we're ready to deploy the CycleCloud Pod.   By default, this deployment will have a public IP.  To disable, the public IP, uncomment the "annotations" in the Service definition in `cyclecloud.yaml`.

> [!IMPORTANT]
> Update the cyclecloud YAML File with the new Managed Identity ID Resource ID and Client ID, and other variables.  The Client ID will change for each terraform cluster deployment even if the rest of the variables are constant.

```bash
SUBSCRIPTION_ID=$( az account show --query id -o tsv )
CLIENT_ID=$( az identity show --resource-group cc-aks-tf-nodes-rg --name cc-aks-tf-ui --query clientId -o tsv )
CYCLECLOUD_USERNAME="your_username"
CYCLECLOUD_PASSWORD="your_password"
CYCLECLOUD_STORAGE="ccstorageuswest2"
CYCLECLOUD_USER_PUBKEY="your SSH pub key here"
CYCLECLOUD_CONTAINER_IMAGE="cccontainerreguswest2.azurecr.io/cyclecloud:latest"

sed -i "s/%SUBSCRIPTION_ID%/${SUBSCRIPTION_ID}/g" ./cyclecloud.yaml
sed -i "s/%CLIENT_ID%/${CLIENT_ID}/g" ./cyclecloud.yaml
sed -i "s/%CYCLECLOUD_USERNAME%/${CYCLECLOUD_USERNAME}/g" ./cyclecloud.yaml
sed -i "s/%CYCLECLOUD_PASSWORD%/${CYCLECLOUD_PASSWORD}/g" ./cyclecloud.yaml
sed -i "s/%CYCLECLOUD_STORAGE%/${CYCLECLOUD_STORAGE}/g" ./cyclecloud.yaml
sed -i "s/%CYCLECLOUD_USER_PUBKEY%/${CYCLECLOUD_USER_PUBKEY}/g" ./cyclecloud.yaml
sed -i "s/%CYCLECLOUD_CONTAINER_IMAGE%/${CYCLECLOUD_CONTAINER_IMAGE}/g" ./cyclecloud.yaml

kubectl apply -f cyclecloud.yaml
```
