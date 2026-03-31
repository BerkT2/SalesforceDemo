@IsTest
global class AloTechMockCallout implements HttpCalloutMock {
    global HTTPResponse respond(HTTPRequest req) {
        HTTPResponse res = new HTTPResponse();
        res.setHeader('Content-Type', 'application/json');
        res.setBody('{"callId": "CALL-MOCK-001", "result": "connected"}');
        res.setStatusCode(200);
        return res;
    }
}
