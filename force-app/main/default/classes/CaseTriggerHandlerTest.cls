@IsTest
private class CaseTriggerHandlerTest {

    @TestSetup
    static void setupData() {
        // Business Account
        Account bizAccount = new Account(
            Name = 'Test Kurumsal',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                           .get('Business_Account').getRecordTypeId(),
            Tax_Number_VKN__c = '12345678901',
            Operator__c = 'WAT Mobilite'
        );
        insert bizAccount;

        // Station Account
        Account station = new Account(
            Name = 'Test İstasyon',
            RecordTypeId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                           .get('Station').getRecordTypeId(),
            ParentId = bizAccount.Id,
            Main_Operator__c = 'WAT Mobilite',
            Usage_Type__c = 'Genel'
        );
        insert station;

        // Station Unit
        Station_Unit__c unit = new Station_Unit__c(
            Related_Station__c = station.Id,
            Unit_Type__c = 'AC'
        );
        insert unit;

        // Parameter - Case Reason L1
        Parameter__c caseReason = new Parameter__c(
            Name = 'Şarj Sorunu',
            RecordTypeId = Schema.SObjectType.Parameter__c.getRecordTypeInfosByDeveloperName()
                           .get('Case_Reason').getRecordTypeId()
        );
        insert caseReason;

        // Parameter - Case Reason Type L2
        Parameter__c caseReasonType = new Parameter__c(
            Name = 'Soket Arızası',
            RecordTypeId = Schema.SObjectType.Parameter__c.getRecordTypeInfosByDeveloperName()
                           .get('Case_Reason_Type').getRecordTypeId(),
            Related_Case_Reason__c = caseReason.Id
        );
        insert caseReasonType;

        // Parameter - Case Reason Type Detail L3
        Parameter__c detail = new Parameter__c(
            Name = 'Soket Giriş Ucu Hasarlı',
            RecordTypeId = Schema.SObjectType.Parameter__c.getRecordTypeInfosByDeveloperName()
                           .get('Case_Reason_Type_Detail').getRecordTypeId(),
            Related_Case_Reason_Type__c = caseReasonType.Id,
            Is_FLS_Eligible__c = true,
            Is_Service_Eligible__c = true,
            Is_Critical__c = false
        );
        insert detail;

        // Script record
        Script__c script = new Script__c(
            Related_Case_Reason__c = caseReason.Id,
            Order_No__c = 1,
            Question__c = 'Şarj başlıyor mu?',
            Guidance__c = 'Müşteriye sorun',
            Unit_Type_Filter__c = 'Tümü'
        );
        insert script;
    }

    @IsTest
    static void testEligibilityFlagsPopulatedOnInsert() {
        Parameter__c detail = [SELECT Id FROM Parameter__c
                               WHERE RecordType.DeveloperName = 'Case_Reason_Type_Detail' LIMIT 1];
        Parameter__c caseReason = [SELECT Id FROM Parameter__c
                                   WHERE RecordType.DeveloperName = 'Case_Reason' LIMIT 1];
        Parameter__c caseReasonType = [SELECT Id FROM Parameter__c
                                       WHERE RecordType.DeveloperName = 'Case_Reason_Type' LIMIT 1];
        Account station = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Station' LIMIT 1];

        Case c = new Case(
            Subject = 'Test Arıza',
            Status = 'Yeni',
            Related_Station__c = station.Id,
            Case_Reason__c = caseReason.Id,
            Case_Reason_Type__c = caseReasonType.Id,
            Case_Reason_Type_Detail__c = detail.Id
        );
        insert c;

        Case inserted = [SELECT Is_FLS_Eligible__c, Is_Service_Eligible__c FROM Case WHERE Id = :c.Id];
        System.assertEquals(true, inserted.Is_FLS_Eligible__c, 'FLS flag should be true');
        System.assertEquals(true, inserted.Is_Service_Eligible__c, 'Service flag should be true');
    }

    @IsTest
    static void testStageWaitingTimeCreatedOnStatusChange() {
        Case c = createTestCase('Yeni');
        insert c;

        Test.startTest();
        c.Status = 'FLS';
        update c;
        Test.stopTest();

        List<Stage_Waiting_Time__c> stages = [SELECT Id, From_Status__c, To_Status__c FROM Stage_Waiting_Time__c WHERE Related_Case__c = :c.Id];
        System.assertEquals(1, stages.size());
        System.assertEquals('Yeni', stages[0].From_Status__c);
        System.assertEquals('FLS', stages[0].To_Status__c);
    }

    @IsTest
    static void testWorkOrderCreatedWhenStatusService() {
        Case c = createTestCase('Yeni');
        c.Is_Service_Eligible__c = true;
        insert c;

        Test.startTest();
        c.Status = 'Service';
        update c;
        Test.stopTest();

        List<Work_Order__c> wos = [SELECT Id FROM Work_Order__c WHERE Case__c = :c.Id];
        System.assertEquals(1, wos.size(), 'Work Order should be created');
    }

    @IsTest
    static void testScriptControllerReturnsSteps() {
        Parameter__c caseReason = [SELECT Id FROM Parameter__c WHERE RecordType.DeveloperName = 'Case_Reason' LIMIT 1];

        Test.startTest();
        List<Script__c> steps = ScriptController.getScriptSteps(caseReason.Id, 'Ford', 'AC');
        Test.stopTest();

        System.assert(!steps.isEmpty(), 'Script steps should be returned');
    }

    @IsTest
    static void testAloTechRestResourcePost() {
        Case c = createTestCase('Yeni');
        insert c;

        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/alotech/v1/call';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
            'callId' => 'CALL-001',
            'callerPhone' => '05001234567',
            'caseId' => c.Id,
            'callDuration' => 5,
            'callCenterPoint' => 90
        }));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        AloTechRestResource.AloTechResponse resp = AloTechRestResource.handleInboundCall();
        Test.stopTest();

        System.assertEquals(true, resp.success);
    }

    @IsTest
    static void testAloTechOutboundCallout() {
        Test.setMock(HttpCalloutMock.class, new AloTechMockCallout());

        Test.startTest();
        AloTechCalloutService.OutboundDialResult result =
            AloTechCalloutService.initiateOutboundDial('05001234567', null, null);
        Test.stopTest();

        System.assertEquals(true, result.success);
    }

    // Helper
    private static Case createTestCase(String status) {
        Parameter__c caseReason = [SELECT Id FROM Parameter__c WHERE RecordType.DeveloperName = 'Case_Reason' LIMIT 1];
        Parameter__c caseReasonType = [SELECT Id FROM Parameter__c WHERE RecordType.DeveloperName = 'Case_Reason_Type' LIMIT 1];
        Parameter__c detail = [SELECT Id FROM Parameter__c WHERE RecordType.DeveloperName = 'Case_Reason_Type_Detail' LIMIT 1];
        Account station = [SELECT Id FROM Account WHERE RecordType.DeveloperName = 'Station' LIMIT 1];

        return new Case(
            Subject = 'Test Case',
            Status = status,
            Related_Station__c = station.Id,
            Case_Reason__c = caseReason.Id,
            Case_Reason_Type__c = caseReasonType.Id,
            Case_Reason_Type_Detail__c = detail.Id
        );
    }
}
