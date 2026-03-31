public with sharing class CaseTriggerHandler {

    // before insert / before update: auto-populate Is_FLS_Eligible__c, Is_Critical__c, Is_Service_Eligible__c
    // from Case_Reason_Type_Detail__c lookup
    public void beforeInsert(List<Case> newCases) {
        populateEligibilityFlags(newCases);
    }

    public void beforeUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        populateEligibilityFlags(newCases);
    }

    private void populateEligibilityFlags(List<Case> cases) {
        Set<Id> detailIds = new Set<Id>();
        for (Case c : cases) {
            if (c.Case_Reason_Type_Detail__c != null) {
                detailIds.add(c.Case_Reason_Type_Detail__c);
            }
        }
        if (detailIds.isEmpty()) return;

        Map<Id, Parameter__c> detailMap = new Map<Id, Parameter__c>(
            [SELECT Id, Is_FLS_Eligible__c, Is_Critical__c, Is_Service_Eligible__c
             FROM Parameter__c WHERE Id IN :detailIds]
        );

        for (Case c : cases) {
            if (c.Case_Reason_Type_Detail__c != null && detailMap.containsKey(c.Case_Reason_Type_Detail__c)) {
                Parameter__c detail = detailMap.get(c.Case_Reason_Type_Detail__c);
                c.Is_FLS_Eligible__c = detail.Is_FLS_Eligible__c;
                c.Is_Critical__c = detail.Is_Critical__c;
                c.Is_Service_Eligible__c = detail.Is_Service_Eligible__c;
            }
        }
    }

    // after insert
    public void afterInsert(List<Case> newCases) {
        checkEscalation(newCases);
    }

    // after update
    public void afterUpdate(List<Case> newCases, Map<Id, Case> oldMap) {
        List<Stage_Waiting_Time__c> stageRecords = new List<Stage_Waiting_Time__c>();
        List<Work_Order__c> workOrders = new List<Work_Order__c>();

        for (Case c : newCases) {
            Case oldCase = oldMap.get(c.Id);
            if (c.Status != oldCase.Status) {
                // Create Stage_Waiting_Time__c record
                stageRecords.add(new Stage_Waiting_Time__c(
                    Related_Case__c = c.Id,
                    From_Status__c = oldCase.Status,
                    To_Status__c = c.Status,
                    Change_DateTime__c = System.now()
                ));

                // Auto-create Work Order when moved to Service
                if (c.Status == 'Service') {
                    workOrders.add(new Work_Order__c(
                        Case__c = c.Id,
                        Subject__c = c.Subject,
                        Description__c = c.Description,
                        Related_Unit__c = c.Related_Station_Unit__c,
                        Status__c = 'Open'
                    ));
                }
            }
        }

        if (!stageRecords.isEmpty()) insert stageRecords;
        if (!workOrders.isEmpty()) insert workOrders;

        checkEscalation(newCases);
    }

    private void checkEscalation(List<Case> cases) {
        List<Id> criticalCaseIds = new List<Id>();
        for (Case c : cases) {
            if (c.Is_Critical__c == true) {
                criticalCaseIds.add(c.Id);
            }
        }
        if (!criticalCaseIds.isEmpty()) {
            EscalationAlertService.sendEscalationEmail(criticalCaseIds);
        }
    }
}
