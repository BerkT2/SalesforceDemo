public with sharing class AloTechCalloutService {

    private static final String NAMED_CREDENTIAL = 'callout:AloTech_API';

    public static String linkCallToCase(Id caseId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/api/case/link');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(JSON.serialize(new Map<String, String>{ 'caseId' => caseId }));

        Http http = new Http();
        HttpResponse res = http.send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('callId');
        }
        throw new AuraHandledException('AloTech API hatası: ' + res.getStatus());
    }

    public static OutboundDialResult initiateOutboundDial(String phoneNumber, Id caseId, Id agentId) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(NAMED_CREDENTIAL + '/api/dial/outbound');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');

        Map<String, Object> payload = new Map<String, Object>{
            'phoneNumber' => phoneNumber,
            'caseId' => caseId,
            'agentId' => agentId
        };
        req.setBody(JSON.serialize(payload));

        Http http = new Http();
        HttpResponse res = http.send(req);

        OutboundDialResult result = new OutboundDialResult();
        if (res.getStatusCode() == 200) {
            Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            result.success = true;
            result.callId = (String) body.get('callId');
            result.dialResult = (String) body.get('result');
        } else {
            result.success = false;
            result.errorMessage = 'HTTP ' + res.getStatusCode() + ': ' + res.getStatus();
        }
        return result;
    }

    public class OutboundDialResult {
        public Boolean success;
        public String callId;
        public String dialResult; // connected, busy, no_answer
        public String errorMessage;
    }
}
