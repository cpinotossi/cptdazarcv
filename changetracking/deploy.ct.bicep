@description('Name for your log analytics workspace')
param prefix string

@description('Azure Region to deploy the Log Analytics Workspace')
param location string

param myObjectId string

param policyDefinitionCTId string = '/providers/Microsoft.Authorization/policySetDefinitions/53448c70-089b-4f52-8f38-89196d7f2de1'
// Needed Roles can be found here: https://www.azadvertizer.net/azpolicyinitiativesadvertizer/53448c70-089b-4f52-8f38-89196d7f2de1.html

@description('Specifies the name of the policy assignment, can be used defined or an idempotent name as the defaultValue provides.')
param policyAssignmentCTName string = guid(policyDefinitionCTId, resourceGroup().name)

resource policyAssignmentCT 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: policyAssignmentCTName
  scope: resourceGroup()
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: policyDefinitionCTId
    displayName: '${prefix}ct'
    description: 'Enable ChangeTracking and Inventory for Arc-enabled virtual machines'
    parameters: {
      Effect: {
        value: 'DeployIfNotExists'
      }
      dcrResourceId: {
        value: dcrCT.id
      }
      // listOfApplicableLocations: {
      //   value: 'westeurope'
      // }
    }
  }
}

// Define role IDs
var MonitorContributorRoleID = '749f88d5-cbae-40b8-bcfc-e573ddc772fa'
var LogAnalyticsContributorRoleID = '92aaf0da-9dab-42b6-94a3-d43ce8d16293'
var azureConnectedMachineResourceAdministratorRoleID = 'cd570a14-e51a-42ad-bac8-bafd67325302'

// Create role assignment for Monitor Contributor
resource pAMonitorRoleAssignmentCT 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(policyAssignmentCTName, 'roleAssignment', MonitorContributorRoleID)
  properties: {
    principalId: policyAssignmentCT.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', MonitorContributorRoleID)
    principalType: 'ServicePrincipal'
  }
}

// Create role assignment for Log Analytics Contributor
resource pALogRoleAssignmentCT 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(policyAssignmentCTName, 'roleAssignment', LogAnalyticsContributorRoleID)
  properties: {
    principalId: policyAssignmentCT.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', LogAnalyticsContributorRoleID)
    principalType: 'ServicePrincipal'
  }
}

// Create role assignment for Azure Connected Machine Resource Administrator
resource pAConnectedMachineRoleAssignmentCT 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(policyAssignmentCTName, 'roleAssignment', azureConnectedMachineResourceAdministratorRoleID)
  properties: {
    principalId: policyAssignmentCT.identity.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      azureConnectedMachineResourceAdministratorRoleID
    )
    principalType: 'ServicePrincipal'
  }
}

resource dcrCT 'Microsoft.Insights/dataCollectionRules@2023-03-11' existing = {
  name: '${prefix}ct'
}

