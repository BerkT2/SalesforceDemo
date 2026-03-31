public with sharing class EscalationAlertService {

    private static final String ESCALATION_EMAIL_TEMPLATE = 'Kritik_Case_Escalation';

    public static void sendEscalationEmail(List<Id> caseIds) {
        List<Case> criticalCases = [
            SELECT Id, CaseNumber, Subject, AccountId, Account.Name, Status, Is_Critical__c
            FROM Case WHERE Id IN :caseIds AND Is_Critical__c = true
        ];
        if (criticalCases.isEmpty()) return;

        List<OrgWideEmailAddress> oweaList = [
            SELECT Id, Address FROM OrgWideEmailAddress LIMIT 1
        ];

        List<User> managers = [
            SELECT Id, Email FROM User
            WHERE UserRole.DeveloperName IN ('Management', 'CEO', 'Director')
            AND IsActive = true LIMIT 10
        ];
        if (managers.isEmpty()) return;

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        for (Case c : criticalCases) {
            for (User mgr : managers) {
                Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setToAddresses(new List<String>{ mgr.Email });
                email.setSubject('KRİTİK VAKA ALERTİ: ' + c.CaseNumber + ' - ' + c.Subject);
                email.setPlainTextBody(
                    'Kritik bir vaka oluşturuldu/güncellendi.\n\n' +
                    'Vaka No: ' + c.CaseNumber + '\n' +
                    'Konu: ' + c.Subject + '\n' +
                    'Müşteri: ' + (c.Account != null ? c.Account.Name : 'Bilinmiyor') + '\n' +
                    'Durum: ' + c.Status + '\n\n' +
                    'Lütfen en kısa sürede ilgilenin.'
                );
                if (!oweaList.isEmpty()) {
                    email.setOrgWideEmailAddressId(oweaList[0].Id);
                }
                emails.add(email);
            }
        }
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}
