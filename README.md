# Azure Arc Demo

## Azure Arc on Vagrant

The following demo is based on the Azure Arc Jumpstart project: https://azurearcjumpstart.com/azure_arc_jumpstart/azure_arc_servers/vagrant/local_vagrant_ubuntu.
We needed to modify some of the scripts to fit our own demo.

### Prerequisites Software

You will need to install certain software on your local PC.

- [Install or update Azure CLI to version 2.53.0 and above](https://learn.microsoft.com/cli/azure/install-azure-cli?view=azure-cli-latest). Use the below command to check your current installed version.

~~~powershell
az --version
~~~

Install Git as described here: https://git-scm.com/book/en/v2/Getting-Started-Installing-Git

~~~powershell
# Install Oracle VirtualBox
winget install -e --id Oracle.VirtualBox
# Install Vagrant
winget install -e --id HashiCorp.Vagrant # did not work, needed to install manually
vagrant # check if vagrant is installed
~~~

### Prerequisites Env

Setup all environment variables we will need during this demo.

~~~powershell
az login # login to your azure account

$prefix="cptdazarcv" # Replace with your prefix
$subname="sub-myedge-03" # Replace with your subscription name
$location = "westeurope" # Replace with your preferred location

# Set subscriptions
az account set --subscription $subname
# Verify the subscription
az account show --query "{subscriptionName:name, subscriptionId:id}"
# Get the current subscription id
$subscriptionId = az account show --query id -o tsv

# install needed Arc resource provider under the current subscription
az provider register --namespace 'Microsoft.HybridCompute'
az provider register --namespace 'Microsoft.GuestConfiguration'
az provider register --namespace 'Microsoft.HybridConnectivity'
az provider register --namespace 'Microsoft.AzureArcData'

# verify service provider installation
az provider show --namespace 'Microsoft.HybridCompute' -o table
az provider show --namespace 'Microsoft.GuestConfiguration' -o table
az provider show --namespace 'Microsoft.HybridConnectivity' -o table
az provider show --namespace 'Microsoft.AzureArcData' -o table

# Create Resource Group
az group create --name $prefix --location $location
~~~

#### Create a Service Principal [SP]

To connect a server to Azure Arc, an Azure service principal assigned with the "Azure Connected Machine Onboarding" role is required. To create it, login to your Azure account run the below command (this can also be done in [Azure Cloud Shell](https://shell.azure.com/)).

~~~powershell
# Create SP and store password, you will need to have the corresponding rights to create a service principal in your subscription or ask your admin to create it for you.
$sppassword= az ad sp create-for-rbac -n $prefix --role "Azure Connected Machine Onboarding" --scopes /subscriptions/$subscriptionId/resourceGroups/$prefix --query password -o tsv

# Verify password
echo $sppassword # show the password

# Retrieve Service Principal Object ID.
$spid=az ad sp list --display-name $prefix --query [0].id -o tsv
$spAppId=az ad sp list --display-name $prefix --query [0].appId -o tsv
# Verify SP assignments
az role assignment list --all --assignee $spid --query "[].{role:roleDefinitionName, scope:scope}" -o table
# Show AppId, aka ServicePrincipalId
az ad sp list --display-name $prefix --query [0].appId -o tsv
~~~

### Connect the VM to Azure Arc

To connect the VM to Azure Arc, we need to run the `azcmagent.connect.sh` script on the VM.
The script "azcmagent.connect.sh" needs to be modified accordently.

### Create the local linux VM via Vagrant

~~~powershell
# Clone the Azure Arc Jumpstart project if you like but it is not necessary for this demo.
git clone https://github.com/microsoft/azure_arc.git
# copy of the corresponding content from the local repo is already done for you.
# cp -r .\azure_arc\azure_arc_servers_jumpstart\local\vagrant .
cd .\vagrant\ubuntu
# Open the Azure Arc config file which will be used to onboard our local VM to Azure Arc.
code .\scripts\azcmagent.connect.sh
~~~

> NOTE: The script "azcmagent.connect.sh" is created as described here https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-service-principal#generate-the-installation-script-from-the-azure-portal

You will need to replace the following values inside "azcmagent.connect.sh" with yours. You already have created in the previous steps or which are provided by Azure directly

~~~powershell
# ServicePrincipalId;
echo $spAppId
# ServicePrincipalClientSecret;
echo $sppassword
# subscriptionId=<YOUR-SUB-ID>;
echo $subscriptionId
# resourceGroup="cptdazarcv";
echo $prefix
# tenantId="<YOUR-TENANT-ID>";
az account show --query tenantId -o tsv
# location="germanywestcentral";
echo $location
~~~

Let´s create our local VM via Vagrant.

~~~powershell
vagrant up
vagrant status # expect "running"
# Verify the file is on the VM
vagrant ssh
azcmagent show # Look for "Agent Status : Connected"
azcmagent check # check the connectivity of the agent
ls -ll /opt/azcmagent/bin/azcmagent # see the agent installation
~~~

### Which user rights does the arc agent have on ubuntu?

~~~bash
ps aux | grep azcmagent
groups himds
cat /etc/passwd | grep himds
~~~

The output himds:x:999:999::/home/himds:/bin/false can be broken down into the following fields:

- Username (himds): This is the name of the user account.
- Password (x): This field typically contains an x, indicating that the encrypted password is stored in the /etc/shadow file, which is more secure.
- User ID (UID) (999): This is the unique identifier for the user. The UID 999 is typically reserved for system users.
- Group ID (GID) (999): This is the unique identifier for the user's primary group. The GID 999 indicates that the user belongs to a system group.
- User Info (::): This field is usually used for storing additional information about the user, such as their full name or contact details. In this case, it is empty.
- Home Directory (/home/himds): This is the path to the user's home directory. For the user himds, it is /home/himds.
- Shell (/bin/false): This is the path to the user's default shell. The value /bin/false indicates that the user does not have access to an interactive shell. This is often used for system or service accounts that do not require shell access.

This output indicates that himds is a system user with no interactive shell access, likely used for running specific services or agents.

~~~bash
cat /etc/group | grep himds
sudo cat /etc/sudoers | grep himds
sudo ls /etc/sudoers.d/
sudo grep himds /etc/sudoers.d/*
himds
~~~

### Get Arc Logs

~~~powershell
vagrant ssh
# Check the logs directly on the vm
sudo tail /var/opt/azcmagent/log/azcmagent.log
sudo tail /var/opt/azcmagent/log/himds.log
sudo tail /var/lib/GuestConfig/arc_policy_logs/gc_agent.log
sudo tail /var/lib/GuestConfig/arc_policy_logs/gc_agent_telemetry.txt
sudo tail /var/lib/GuestConfig/arc_policy_logs/gc_worker.log
sudo tail /var/lib/GuestConfig/arc_policy_logs/gc_worker_telemetry.txt
sudo tail /var/lib/GuestConfig/extension_logs
sudo tail /var/lib/GuestConfig/extension_reports
sudo tail /var/lib/GuestConfig/ext_mgr_logs
sudo azcmagent logs # collect logs and combine them in a zip file
exit
# copy the zip file from the vagrant vm to the host
vagrant scp :/home/vagrant/azcmagent-logs-240731T1021-cptdazarcv.zip .
# unzip the file, use the date inside the filename to create a corresponding folder
Expand-Archive -Path .\azcmagent-logs-240731T1021-cptdazarcv.zip -DestinationPath .\extracted_logs\240731T1021
~~~

### SSH into the VM via Azure

Based on https://learn.microsoft.com/en-us/azure/azure-arc/servers/ssh-arc-overview?tabs=azure-cli

~~~powershell
# Assign myself the Role Virtual Machine User Login, so we will be able to SSH into the VM via Azure as Admin.
$currentUserObjectId=az ad signed-in-user show --query id -o tsv
az role assignment create --assignee $currentUserObjectId --role "Virtual Machine Administrator Login" --scope /subscriptions/$subscriptionId/resourceGroups/$prefix

# Install the Azure CLI extension to be able to install extensions on Arc VMs
az extension add --name connectedmachine

# Install the AADSSH extension
az connectedmachine extension create --name AADSSHLoginForLinux --machine-name $prefix -g $prefix --subscription $subscriptionId --publisher Microsoft.Azure.ActiveDirectory --type AADSSHLoginForLinux --type-handler-version 1.0

# Verify the installation
az connectedmachine extension list --machine-name $prefix -g $prefix -o table

# SSH into the VM via Azure
# ssh-keygen -R cptdazarcv # In case you have already connected to the VM via SSH and you want to remove the key from the known_hosts file.
az ssh arc --subscription $subname --resource-group $prefix --name $prefix # NOTE: I needed to update the current Service Configuration to allow the SSH connection.
sudo azcmagent show
sudo azcmagent logs # collect logs and combine them in a zip file
exit
# copy the zip file from the vagrant vm to the host
cd .\vagrant\ubuntu # switch back to the vagrant folder if not already done
vagrant scp :/home/ga/azcmagent-logs-240731T1034-cptdazarcv.zip .
# unzip the file
Expand-Archive -Path .\azcmagent-logs-240731T1034-cptdazarcv.zip -DestinationPath .\extracted_logs\240731T1034
~~~

### Policy to install the Azure Monitor Agent

~~~powershell
cd ..\..\ # in case you did the vagrant exercise move back to the root folder
# copy the relevant files from the local repo
# cp -r .\azure_arc\azure_arc_servers_jumpstart\policies . # already done for you
az deployment group create -g $prefix -f "policies\deploy.bicep" --parameters prefix=$prefix location=$location
# it will take a while till the policy is applied
# Verify the policy with the scope of our resource group
az policy state list --resource-group $prefix --query "[?policySetDefinitionId=='/providers/Microsoft.Authorization/policySetDefinitions/2b00397d-c309-49c4-aa5a-f0b2c5bc6321'].{policyDefinitionReferenceId:policyDefinitionReferenceId,policyDefinitionId:policyDefinitionId,timestamp:timestamp,complianceState:complianceState}" # Expect two "NonCompliant" entries.
# Verify if extension is installed
az connectedmachine extension list --machine-name $prefix -g $prefix -o table # AMA will not show up
# Revalidate the policy, this can take some time and should only be done if really needed during the demo.
az policy state trigger-scan --resource-group $prefix
# Get policy assignment Name
$policyAssignmentId=az policy assignment list -g $prefix --query "[?displayName=='cptdazarcvama'].id" -o tsv
# Run the az policy state list command and capture the output in an Array
$policyStates = az policy state list -g $prefix --query "[?policySetDefinitionId=='/providers/Microsoft.Authorization/policySetDefinitions/2b00397d-c309-49c4-aa5a-f0b2c5bc6321'].{policyAssignmentId:policyAssignmentId,policyDefinitionReferenceId:policyDefinitionReferenceId}" | ConvertFrom-Json
# Create a remediation task for each policy which is part of the policy set and relevant.
az policy remediation create -n "${prefix}-AMA-DCR" --policy-assignment $policyStates[0].policyAssignmentId --definition-reference-id $policyStates[0].policyDefinitionReferenceId -g $prefix --resource-discovery-mode ReEvaluateCompliance
az policy remediation create -n "${prefix}-AMA" --policy-assignment $policyStates[0].policyAssignmentId --definition-reference-id $policyStates[1].policyDefinitionReferenceId -g $prefix --resource-discovery-mode ReEvaluateCompliance
~~~

Duration: Remediation tasks can take from a few minutes to several hours.
The duration of an Azure remediation task can vary significantly depending on several factors, including the complexity of the policy, the number of resources affected, and the current load on Azure services. Generally, it can take anywhere from a few minutes to several hours.

Factors Affecting Remediation Task Duration:

- Number of Resources: More resources will generally increase the time required.
- Policy Complexity: Complex policies with multiple conditions and actions may take longer to evaluate and apply.
- Azure Service Load: The current load on Azure services can affect the time it takes to complete remediation tasks.
- Resource Discovery Mode: The mode used for resource discovery (ReEvaluateCompliance or ExistingNonCompliant) can also impact the duration.

Monitoring Remediation Task Status
You can monitor the status of a remediation task using the Azure CLI:

~~~powershell
az policy remediation show -g $prefix -n "${prefix}-AMA-DCR" -o table --query "{name:name,policyDefinitionReferenceId:policyDefinitionReferenceId,provisioningState:provisioningState}"
az policy remediation show -g $prefix -n "${prefix}-AMA" -o table --query "{name:name,policyDefinitionReferenceId:policyDefinitionReferenceId,provisioningState:provisioningState}"
~~~

After all remediation tasks are completed, you can verify things.

~~~powershell
# Verify if extension is installed
az connectedmachine extension list --machine-name $prefix -g $prefix -o table # AMA will not show up
# Verify the policy with the scope of our resource group
# Verify the policy with the scope of our resource group
az policy state list --resource-group $prefix --query "[?policySetDefinitionId=='/providers/Microsoft.Authorization/policySetDefinitions/2b00397d-c309-49c4-aa5a-f0b2c5bc6321'].{policyDefinitionReferenceId:policyDefinitionReferenceId,policyDefinitionId:policyDefinitionId,timestamp:timestamp,complianceState:complianceState}" # Expect two "Compliant" entries.
~~~

### Azure Arc and Change Tracking

~~~powershell
# show changes introduced by arc agent
# SSH into the VM via Azure
az ssh arc --subscription $subname --resource-group $prefix --name $prefix
# List directory which contains the Azure Arc extension packages and their configuration files.
ls /var/lib/waagent/
# AMA Config files
ls /etc/opt/microsoft/azuremonitoragent
ls /etc/opt/microsoft/azuremonitoragent/amacoreagent/PA.json
exit
az deployment group create -g $prefix -f "changetracking\deploy.bicep" --parameters prefix=$prefix location=$location myObjectId=$currentUserObjectId

# Get policy assignment Name
az policy assignment show -g $prefix -n "3ac2c636-a54b-5e62-b0da-892dd4b49122" --query displayName -o tsv
$policyAssignmentId=az policy assignment list -g $prefix --query "[?displayName=='cptdazarcvct'].id" -o tsv

az policy state list --resource-group $prefix --query "[?complianceState=='NonCompliant'].{policyDefinitionReferenceId:policyDefinitionReferenceId,policyDefinitionId:policyDefinitionId,timestamp:timestamp,complianceState:complianceState}" # Expect two "NonCompliant" entries.

az policy state list --resource-group $prefix --query "[?policySetDefinitionName=='53448c70-089b-4f52-8f38-89196d7f2de1'].{policyDefinitionReferenceId:policyDefinitionReferenceId,policyDefinitionId:policyDefinitionId,timestamp:timestamp,complianceState:complianceState}" # Expect two "NonCompliant" entries.

$policyStates = az policy state list -g $prefix --query "[?policySetDefinitionName=='53448c70-089b-4f52-8f38-89196d7f2de1'].{policyAssignmentId:policyAssignmentId,policyDefinitionReferenceId:policyDefinitionReferenceId}" | ConvertFrom-Json

# Create a remediation task for each policy which is part of the policy set and relevant.
az policy remediation create -n "${prefix}-CT-AMA" --policy-assignment $policyStates[0].policyAssignmentId --definition-reference-id $policyStates[0].policyDefinitionReferenceId -g $prefix --resource-discovery-mode ReEvaluateCompliance

az policy remediation create -n "${prefix}-CT" --policy-assignment $policyStates[0].policyAssignmentId --definition-reference-id $policyStates[1].policyDefinitionReferenceId -g $prefix --resource-discovery-mode ReEvaluateCompliance

az policy remediation create -n "${prefix}-CT-DCR" --policy-assignment $policyStates[0].policyAssignmentId --definition-reference-id $policyStates[2].policyDefinitionReferenceId -g $prefix --resource-discovery-mode ReEvaluateCompliance


az policy remediation show -g $prefix -n "${prefix}-CT" -o table --query "{name:name,policyDefinitionReferenceId:policyDefinitionReferenceId,provisioningState:provisioningState}"
az policy remediation show -g $prefix -n "${prefix}-CT-AMA" -o table --query "{name:name,policyDefinitionReferenceId:policyDefinitionReferenceId,provisioningState:provisioningState}"
az policy remediation show -g $prefix -n "${prefix}-CT-DCR" -o table --query "{name:name,policyDefinitionReferenceId:policyDefinitionReferenceId,provisioningState:provisioningState}"

# Verify if extension is installed
az connectedmachine extension list --machine-name $prefix -g $prefix -o table # AMA will not show up
~~~



### Azure Arc and Update Manager

~~~powershell
# get azure resource
az resource show -g $prefix -n $prefix --resource-type Microsoft.HybridCompute/machines > arc.vm.json
code arc.vm.json
# show changes introduced by arc agent
# SSH into the VM via Azure
az ssh arc --subscription $subname --resource-group $prefix --name $prefix
apt list --upgradable
exit
az deployment group create -g $prefix -f "updatemanager\deploy.checking.bicep" --parameters prefix=$prefix location=$location

# List directory which contains the Azure Arc extension packages and their configuration files.
ls /var/lib/waagent/
# AMA Config files
ls /etc/opt/microsoft/azuremonitoragent
ls /etc/opt/microsoft/azuremonitoragent/amacoreagent/PA.json

~~~

### Clean up

~~~powershell
# Delete role assignment
$policyAssignmentSP=az policy assignment list -g $prefix --query "[?displayName=='${prefix}ama'].identity.principalId" -o tsv
$roleAssignmentArray=az role assignment list --assignee $policyAssignmentSP -g $prefix --query "[].{id:id,assignee:principalId,role:roleDefinitionName}" | ConvertFrom-Json

# Delete the role assignments in a for loop
foreach ($roleAssignment in $roleAssignmentArray) {
    az role assignment delete --ids $roleAssignment.id
}

$policyAssignmentSPCT=az policy assignment list -g $prefix --query "[?displayName=='${prefix}ct'].identity.principalId" -o tsv
$roleAssignmentCTArray=az role assignment list --assignee $policyAssignmentSPCT -g $prefix --query "[].{id:id,assignee:principalId,role:roleDefinitionName}" | ConvertFrom-Json

# Delete the role assignments in a for loop
foreach ($roleAssignmentCT in $roleAssignmentCTArray) {
    az role assignment delete --ids $roleAssignmentCT.id
}

az group delete --name $prefix --yes --no-wait
vagrant box list
vagrant box remove ubuntu/xenial64
~~~

## Misc

### AMA Debugging

By looking into the Change Tracking we did figure out that the AMA is not running. We had some issues with the local VM and it seems like AMA has been affected.

Based on https://github.com/Azure/azure-linux-extensions/blob/master/AzureMonitorAgent/ama_tst/AMA-Troubleshooting-Tool.md

~~~powershell
# show current status of AMA agent
az connectedmachine extension show -n AzureMonitorLinuxAgent --machine-name $prefix -g $prefix
# az ssh arc --subscription $subname --resource-group $prefix --name $prefix
vagrant ssh
sudo su - # folder is owned by root
systemctl status azuremonitoragent
~~~

Another way to check the status of the agent is to use the AMA Troubleshooting Tool.

~~~bash
cd /var/lib/waagent/Microsoft.Azure.Monitor.AzureMonitorLinuxAgent-1.31.1/ama_tst
sudo sh ama_troubleshooter.sh
sudo journalctl -u azuremonitoragent

sudo ls /etc/opt/microsoft/azuremonitoragent/config-cache/configchunks/
sudo cat /etc/opt/microsoft/azuremonitoragent/config-cache/configchunks/2871056244766261301.json
~~~

### github

~~~powershell
git init
git status
git add *
git config --global init.defaultBranch main
gh repo create $prefix --public
git remote add origin https://github.com/cpinotossi/$prefix.git
git remote -v
git add .gitignore
git add *
git status

git commit -m"initial commit"
git push origin main
~~~
