@RestResource(urlMapping='/alotech/v1/*')
global with sharing class AloTechRestResource {

    @HttpPost
    global static AloTechResponse handleInboundCall() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;

        AloTechResponse response = new AloTechResponse();
        try {
            String body = req.requestBody.toString();
            AloTechCallPayload payload = (AloTechCallPayload) JSON.deserialize(body, AloTechCallPayload.class);

            // Match contact by phone
            List<Contact> contacts = [
                SELECT Id, AccountId, Account.Name
                FROM Contact WHERE MobilePhone = :payload.callerPhone OR Phone = :payload.callerPhone
                LIMIT 1
            ];

            // Create Task (Log a Call)
            Task callTask = new Task();
            callTask.Subject = 'AloTech Çağrı - ' + payload.callId;
            callTask.Status = 'Completed';
            callTask.ActivityDate = Date.today();
            callTask.Call_Start_DateTime__c = payload.callStartDateTime;
            callTask.Call_End_DateTime__c = payload.callEndDateTime;
            callTask.Call_Duration__c = payload.callDuration;
            callTask.Voice_URL__c = payload.voiceUrl;
            callTask.Call_Center_Point__c = payload.callCenterPoint;
            callTask.TaskSubtype = 'Call';

            if (!contacts.isEmpty()) {
                callTask.WhoId = contacts[0].Id;
            }
            if (String.isNotBlank(payload.caseId)) {
                callTask.Related_Case__c = Id.valueOf(payload.caseId);
                callTask.WhatId = Id.valueOf(payload.caseId);
            }

            insert callTask;

            response.success = true;
            response.taskId = callTask.Id;
            response.message = 'Task created successfully';
        } catch (Exception e) {
            res.statusCode = 500;
            response.success = false;
            response.message = e.getMessage();
        }
        return response;
    }

    @HttpGet
    global static DealerInfoResponse getDealerCaseInfo() {
        RestRequest req = RestContext.request;
        String callerPhone = req.params.get('phone');

        DealerInfoResponse resp = new DealerInfoResponse();
        try {
            List<Account> dealers = [
                SELECT Id, Name, Phone, (SELECT Id, CaseNumber, Subject, Status FROM Cases WHERE IsClosed = false ORDER BY CreatedDate DESC LIMIT 5)
                FROM Account WHERE RecordType.DeveloperName = 'Business_Account' AND Phone = :callerPhone LIMIT 1
            ];
            if (!dealers.isEmpty()) {
                resp.dealerName = dealers[0].Name;
                resp.dealerId = dealers[0].Id;
                resp.openCases = new List<CaseInfo>();
                for (Case c : dealers[0].Cases) {
                    CaseInfo ci = new CaseInfo();
                    ci.caseId = c.Id;
                    ci.caseNumber = c.CaseNumber;
                    ci.subject = c.Subject;
                    ci.status = c.Status;
                    resp.openCases.add(ci);
                }
            }
            resp.success = true;
        } catch (Exception e) {
            resp.success = false;
            resp.message = e.getMessage();
        }
        return resp;
    }

    global class AloTechCallPayload {
        global String callId;
        global String callerPhone;
        global String caseId;
        global DateTime callStartDateTime;
        global DateTime callEndDateTime;
        global Integer callDuration;
        global String voiceUrl;
        global Decimal callCenterPoint;
    }

    global class AloTechResponse {
        global Boolean success;
        global String taskId;
        global String message;
    }

    global class DealerInfoResponse {
        global Boolean success;
        global String message;
        global String dealerId;
        global String dealerName;
        global List<CaseInfo> openCases;
    }

    global class CaseInfo {
        global String caseId;
        global String caseNumber;
        global String subject;
        global String status;
    }
}
