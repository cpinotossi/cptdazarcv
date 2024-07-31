@description('Name for your log analytics workspace')
param prefix string

@description('Azure Region to deploy the Log Analytics Workspace')
param location string

@description('Specifies the ID of the policy definition or policy set definition being assigned.')
param policyDefinitionID string = '/providers/Microsoft.Authorization/policySetDefinitions/2b00397d-c309-49c4-aa5a-f0b2c5bc6321' // Display Name: Enable Azure Monitor for Hybrid VMs with AMA
// Needed Roles can be found here: https://www.azadvertizer.net/azpolicyinitiativesadvertizer/2b00397d-c309-49c4-aa5a-f0b2c5bc6321.html

@description('Specifies the name of the policy assignment, can be used defined or an idempotent name as the defaultValue provides.')
param policyAssignmentName string = guid(policyDefinitionID, resourceGroup().name)

resource law 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: prefix
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource policyAssignment 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: policyAssignmentName
  scope: resourceGroup()
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: policyDefinitionID
    displayName: '${prefix}ama'
    description: 'Enable Azure Monitor for Hybrid VMs with AMA'
    nonComplianceMessages:[
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
        value: dcr.id
      }
    }
  }
}

// Define role IDs
var MonitorContributorRoleID = '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
var LogAnalyticsContributorRoleID = '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
var azureConnectedMachineResourceAdministratorRoleID = 'cd570a14-e51a-42ad-bac8-bafd67325302'

// Create role assignment for Monitor Contributor
resource pAMonitorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(policyAssignmentName, 'roleAssignment', MonitorContributorRoleID)
  properties: {
    principalId: policyAssignment.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', MonitorContributorRoleID)
    principalType:'ServicePrincipal'
  }
}

// Create role assignment for Log Analytics Contributor
resource pALogRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(policyAssignmentName, 'roleAssignment', LogAnalyticsContributorRoleID)
  properties: {
    principalId: policyAssignment.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', LogAnalyticsContributorRoleID)
    principalType:'ServicePrincipal'
  }
}

// Create role assignment for Azure Connected Machine Resource Administrator
resource pAConnectedMachineRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(policyAssignmentName, 'roleAssignment', azureConnectedMachineResourceAdministratorRoleID)
  properties: {
    principalId: policyAssignment.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', azureConnectedMachineResourceAdministratorRoleID)
    principalType:'ServicePrincipal'
  }
}

resource dcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: prefix
  location: 'germanywestcentral'
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
          name: '${prefix}sysLogsDataSource'
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


// resource dcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
//   name: name
//   location: location
//   kind: 'Linux'
//   properties: {
//     dataSources: {
//       performanceCounters: [
//         {
//           streams: [
//             'Microsoft-InsightsMetrics'
//           ]
//           samplingFrequencyInSeconds: 60
//           counterSpecifiers: [
//             '\\VmInsights\\DetailedMetrics'
//           ]
//           name: 'VMInsightsPerfCounters'
//         }
//       ]
//       syslog: [
//         {
//           streams: [
//             'Microsoft-Syslog'
//           ]
//           facilityNames: [
//             'daemon'
//             'syslog'
//             'user'
//           ]
//           logLevels: [
//             'Info'
//             'Notice'
//             'Warning'
//             'Error'
//             'Critical'
//             'Alert'
//             'Emergency'
//           ]
//           name: 'sysLogsDataSource--1469397783'
//         }
//       ]
//       extensions: [
//         {
//           streams: [
//             'Microsoft-ServiceMap'
//           ]
//           extensionName: 'DependencyAgent'
//           extensionSettings: {}
//           name: 'DependencyAgentDataSource'
//         }
//       ]
//     }
//     destinations: {
//       logAnalytics: [
//         {
//           workspaceResourceId: law.id
//           name: 'VMInsightsPerf-Logs-Dest'
//         }
//         {
//           workspaceResourceId: law.id
//           name: '${name}-law-1'
//         }
//       ]
//     }
//     dataFlows: [
//       {
//         streams: [
//           'Microsoft-Perf'
//         ]
//         destinations: [
//           'VMInsightsPerf-Logs-Dest'
//         ]
//         transformKql: 'source'
//         outputStream: 'Microsoft-Perf'
//       }
//       {
//         streams: [
//           'Microsoft-Syslog'
//         ]
//         destinations: [
//           '${name}-law-1'
//         ]
//         transformKql: 'source'
//         outputStream: 'Microsoft-Syslog'
//       }
//     ]
//   }
// }



