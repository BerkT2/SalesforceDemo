public with sharing class ScriptController {

    @AuraEnabled(cacheable=true)
    public static List<Script__c> getScriptSteps(
        Id caseReasonId,
        String vehicleBrand,
        String unitType
    ) {
        String query = 'SELECT Id, Name, Order_No__c, Question__c, Info_Note__c, Guidance__c, ' +
                       'Vehicle_Brand_Model__c, Unit_Type_Filter__c ' +
                       'FROM Script__c WHERE Related_Case_Reason__c = :caseReasonId ';

        List<String> filters = new List<String>();
        if (String.isNotBlank(vehicleBrand)) {
            filters.add('(Vehicle_Brand_Model__c = :vehicleBrand OR Vehicle_Brand_Model__c = \'Tümü\' OR Vehicle_Brand_Model__c = null)');
        }
        if (String.isNotBlank(unitType)) {
            filters.add('(Unit_Type_Filter__c = :unitType OR Unit_Type_Filter__c = \'Tümü\' OR Unit_Type_Filter__c = null)');
        }
        if (!filters.isEmpty()) {
            query += ' AND ' + String.join(filters, ' AND ');
        }
        query += ' ORDER BY Order_No__c ASC';

        return Database.query(query);
    }

    @AuraEnabled(cacheable=true)
    public static List<Case> getOpenCasesForStation(Id stationId, Id caseReasonId) {
        return [
            SELECT Id, CaseNumber, Subject, Status, CreatedDate
            FROM Case
            WHERE Related_Station__c = :stationId
            AND Case_Reason__c = :caseReasonId
            AND IsClosed = false
            LIMIT 10
        ];
    }
}
