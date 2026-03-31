import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getOpenCasesForStation from '@salesforce/apex/ScriptController.getOpenCasesForStation';
import STATION_FIELD from '@salesforce/schema/Case.Related_Station__c';
import CASE_REASON_FIELD from '@salesforce/schema/Case.Case_Reason__c';

const CASE_FIELDS = [STATION_FIELD, CASE_REASON_FIELD];

export default class DuplicateCaseWarning extends LightningElement {
    @api recordId;
    @track duplicateCases = [];

    stationId;
    caseReasonId;

    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    wiredCase({ data, error }) {
        if (data) {
            const stId = getFieldValue(data, STATION_FIELD);
            const crId = getFieldValue(data, CASE_REASON_FIELD);
            if (stId && crId && (stId !== this.stationId || crId !== this.caseReasonId)) {
                this.stationId = stId;
                this.caseReasonId = crId;
                this.checkDuplicates();
            }
        }
    }

    checkDuplicates() {
        getOpenCasesForStation({
            stationId: this.stationId,
            caseReasonId: this.caseReasonId
        })
        .then(result => {
            this.duplicateCases = result
                .filter(c => c.Id !== this.recordId)
                .map(c => ({
                    ...c,
                    url: '/lightning/r/Case/' + c.Id + '/view'
                }));
        })
        .catch(() => {
            this.duplicateCases = [];
        });
    }

    get showWarning() {
        return this.duplicateCases && this.duplicateCases.length > 0;
    }

    get duplicateCount() {
        return this.duplicateCases ? this.duplicateCases.length : 0;
    }
}
