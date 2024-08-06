# Add the service principal application ID and secret here
ServicePrincipalId="<YOUR-SP-APPID>";
ServicePrincipalClientSecret="<YOUR-SP-SECRET>";


export subscriptionId="<YOUR-SUB-ID>";
export resourceGroup="cptdazarcv";
export tenantId="<YOUR-TENANT-ID>";
export location="germanywestcentral";
export authType="principal";
export correlationId="eaf30af3-fb1e-479d-b60e-dcd3ee8f96a1";
export cloud="AzureCloud";
output=$(wget https://aka.ms/azcmagent -O /tmp/install_linux_azcmagent.sh 2>&1);
if [ $? != 0 ]; then wget -qO- --method=PUT --body-data="{\"subscriptionId\":\"$subscriptionId\",\"resourceGroup\":\"$resourceGroup\",\"tenantId\":\"$tenantId\",\"location\":\"$location\",\"correlationId\":\"$correlationId\",\"authType\":\"$authType\",\"operation\":\"onboarding\",\"messageType\":\"DownloadScriptFailed\",\"message\":\"$output\"}" "https://gbl.his.arc.azure.com/log" &> /dev/null || true; fi;
echo "$output";
bash /tmp/install_linux_azcmagent.sh;
sudo azcmagent connect --service-principal-id "$ServicePrincipalId" --service-principal-secret "$ServicePrincipalClientSecret" --resource-group "$resourceGroup" --tenant-id "$tenantId" --location "$location" --subscription-id "$subscriptionId" --cloud "$cloud" --tags "Datacenter=cptdazarc2,City=munich,StateOrDistrict=bavaria,CountryOrRegion=germany,ArcSQLServerExtensionDeployment=Disabled" --correlation-id "$correlationId";