@description('Name for your log analytics workspace')
param prefix string

@description('Azure Region to deploy the Log Analytics Workspace')
param location string

@description('Specifies the ID of the policy definition or policy set definition being assigned.')
param policyDefinitionUMPCId string = '/providers/Microsoft.Authorization/policyDefinitions/bfea026e-043f-4ff4-9d1b-bf301ca7ff46' // Display Name: Configure periodic checking for missing system updates on azure Arc-enabled servers
// Needed Roles can be found here: https://www.azadvertizer.net/azpolicyadvertizer/bfea026e-043f-4ff4-9d1b-bf301ca7ff46.html

@description('Specifies the name of the policy assignment, can be used defined or an idempotent name as the defaultValue provides.')
param policyDefinitionUMPCName string = guid(policyDefinitionUMPCId, resourceGroup().name)

var arcVmTag = {
  City: 'munich'
  ArcSQLServerExtensionDeployment: 'Disabled'
}

resource policyAssignmentUMPC 'Microsoft.Authorization/policyAssignments@2023-04-01' = {
  name: policyDefinitionUMPCName
  scope: resourceGroup()
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    policyDefinitionId: policyDefinitionUMPCId
    displayName: '${prefix}umpc'
    description: 'Configure periodic checking for missing system updates on azure Arc-enabled servers'
    parameters: {
      assessmentMode: {
        value: 'AutomaticByPlatform'
      }
      osType: {
        value: 'Linux'
      }
      locations: {
        value: [location]
      }
      tagValues: {
        value: arcVmTag
      }
      tagOperator: {
        value: 'All'
      }
    }
  }
}

// Define role IDs
var azureConnectedMachineResourceAdministratorRoleID = 'cd570a14-e51a-42ad-bac8-bafd67325302'

// Create role assignment for Azure Connected Machine Resource Administrator
resource pAConnectedMachineRoleAssignmentUMPC 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(policyDefinitionUMPCName, 'roleAssignment', azureConnectedMachineResourceAdministratorRoleID)
  properties: {
    principalId: policyAssignmentUMPC.identity.principalId
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      azureConnectedMachineResourceAdministratorRoleID
    )
    principalType: 'ServicePrincipal'
  }
}
