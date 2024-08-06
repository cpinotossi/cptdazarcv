@description('Name for your log analytics workspace')
param prefix string

@description('Azure Region to deploy the Log Analytics Workspace')
param location string

param myObjectId string

@description('Specifies the ID of the policy definition or policy set definition being assigned.')
param policyDefinitionAMAId string = '/providers/Microsoft.Authorization/policySetDefinitions/2b00397d-c309-49c4-aa5a-f0b2c5bc6321' // Display Name: Enable Azure Monitor for Hybrid VMs with AMA
// Needed Roles can be found here: https://www.azadvertizer.net/azpolicyinitiativesadvertizer/2b00397d-c309-49c4-aa5a-f0b2c5bc6321.html

@description('Specifies the name of the policy assignment, can be used defined or an idempotent name as the defaultValue provides.')
param policyAssignmentAMAName string = guid(policyDefinitionAMAId, resourceGroup().name)

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: prefix
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource policyAssignmentAMA 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: policyAssignmentAMAName
  scope: resourceGroup()
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: policyDefinitionAMAId
    displayName: '${prefix}ama'
    description: 'Enable Azure Monitor for Hybrid VMs with AMA'
    nonComplianceMessages: [
      {
        message: 'Azure Monitor for VMs is not enabled'
        policyDefinitionReferenceId: 'AzureMonitorAgent_Linux_HybridVM_Deploy'
      }
      {
        message: 'Data Collection Rule is not associated'
        policyDefinitionReferenceId: 'DataCollectionRuleAssociation_Linux'
      }
    ]
    parameters: {
      Effect: {
        value: 'DeployIfNotExists'
      }
      dcrResourceId: {
        value: dcrAMA.id
      }
    }
  }
}


// Define role IDs
var MonitorContributorRoleID = '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
var LogAnalyticsContributorRoleID = '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
var azureConnectedMachineResourceAdministratorRoleID = 'cd570a14-e51a-42ad-bac8-bafd67325302'

// Create role assignment for Monitor Contributor
resource pAMonitorRoleAssignmentAMA 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(policyAssignmentAMAName, 'roleAssignment', MonitorContributorRoleID)
  properties: {
    principalId: policyAssignmentAMA.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', MonitorContributorRoleID)
    principalType: 'ServicePrincipal'
  }
}

// Create role assignment for Log Analytics Contributor
resource pALogRoleAssignmentAMA 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(policyAssignmentAMAName, 'roleAssignment', LogAnalyticsContributorRoleID)
  properties: {
    principalId: policyAssignmentAMA.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', LogAnalyticsContributorRoleID)
    principalType: 'ServicePrincipal'
  }
}

// Create role assignment for Azure Connected Machine Resource Administrator
resource pAConnectedMachineRoleAssignmentAMA 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(policyAssignmentAMAName, 'roleAssignment', azureConnectedMachineResourceAdministratorRoleID)
  properties: {
    principalId: policyAssignmentAMA.identity.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      azureConnectedMachineResourceAdministratorRoleID
    )
    principalType: 'ServicePrincipal'
  }
}

resource dcrAMA 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: prefix
  location: location
  kind: 'Linux'
  properties: {
    dataSources: {
      syslog: [
        {
          streams: [
            'Microsoft-Syslog'
          ]
          facilityNames: [
            'alert'
            'audit'
            'auth'
            'authpriv'
            'clock'
            'cron'
            'daemon'
            'ftp'
            'kern'
            'local0'
            'local1'
            'local2'
            'local3'
            'local4'
            'local5'
            'local6'
            'local7'
            'lpr'
            'mail'
            'news'
            'nopri'
            'ntp'
            'syslog'
            'user'
            'uucp'
          ]
          logLevels: [
            'Debug'
            'Info'
            'Notice'
            'Warning'
            'Error'
            'Critical'
            'Alert'
            'Emergency'
          ]
          name: 'sysLogsDataSource-1688419672'
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: law.id
          name: '${prefix}SyslogDest'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Syslog'
        ]
        destinations: [
          '${prefix}SyslogDest'
        ]
        transformKql: 'source'
        outputStream: 'Microsoft-Syslog'
      }
    ]
  }
}

resource sa 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: prefix
  location: 'germanywestcentral'
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    dnsEndpointType: 'Standard'
    defaultToOAuthAuthentication: false
    publicNetworkAccess: 'Disabled'
    allowCrossTenantReplication: false
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    largeFileSharesState: 'Enabled'
    networkAcls: {
      // resourceAccessRules: [
      //   {
      //     tenantId: '0ba83d3d-0644-4916-98c0-d513e10dc917'
      //     resourceId: '/subscriptions/f474dec9-5bab-47a3-b4d3-e641dac87ddb/providers/Microsoft.Security/datascanners/storageDataScanner'
      //   }
      // ]
      bypass: 'None'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Deny'
    }
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource sabs 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: sa
  name: 'default'
  properties: {
    cors: {
      corsRules: []
    }
  }
}

resource sabsc 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: sabs
  name: prefix
  properties: {
    immutableStorageWithVersioning: {
      enabled: false
    }
    publicAccess: 'None'
  }
}

resource arcVM 'Microsoft.HybridCompute/machines@2023-10-03-preview' existing = {
  name: prefix
}

var storageBlobDataContributorRoleID = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor

// Create role assignment for Monitor Contributor
resource gaSABlobRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('ga', 'roleAssignment', storageBlobDataContributorRoleID)
  scope: sa
  properties: {
    principalId: myObjectId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageBlobDataContributorRoleID
    )
    principalType: 'User'
  }
}

resource vmSABlobRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('vm', 'roleAssignment', storageBlobDataContributorRoleID)
  scope: sa
  properties: {
    principalId: arcVM.identity.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageBlobDataContributorRoleID
    )
    principalType: 'ServicePrincipal'
  }
}
