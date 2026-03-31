import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import getScriptSteps from '@salesforce/apex/ScriptController.getScriptSteps';

import CASE_REASON_DETAIL_FIELD from '@salesforce/schema/Case.Case_Reason_Type_Detail__c';
import CASE_VEHICLE_BRAND_FIELD from '@salesforce/schema/Case.Vehicle_Brand_Model__c';
import CASE_STATION_UNIT_FIELD from '@salesforce/schema/Case.Related_Station_Unit__c';

const CASE_FIELDS = [CASE_REASON_DETAIL_FIELD, CASE_VEHICLE_BRAND_FIELD, CASE_STATION_UNIT_FIELD];

export default class ScriptViewer extends LightningElement {
    @api recordId;
    @track scriptSteps = [];
    @track isLoading = false;
    @track error;

    caseReasonDetailId;
    vehicleBrand;

    @wire(getRecord, { recordId: '$recordId', fields: CASE_FIELDS })
    wiredCase({ error, data }) {
        if (data) {
            const detailId = getFieldValue(data, CASE_REASON_DETAIL_FIELD);
            const brand = getFieldValue(data, CASE_VEHICLE_BRAND_FIELD);

            if (detailId !== this.caseReasonDetailId || brand !== this.vehicleBrand) {
                this.caseReasonDetailId = detailId;
                this.vehicleBrand = brand;
                this.loadScriptSteps();
            }
        } else if (error) {
            this.error = error;
        }
    }

    loadScriptSteps() {
        if (!this.caseReasonDetailId) {
            this.scriptSteps = [];
            return;
        }
        this.isLoading = true;
        getScriptSteps({
            caseReasonId: this.caseReasonDetailId,
            vehicleBrand: this.vehicleBrand,
            unitType: null
        })
        .then(result => {
            this.scriptSteps = result;
            this.error = undefined;
        })
        .catch(error => {
            this.error = error;
            this.scriptSteps = [];
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    get hasSteps() {
        return this.scriptSteps && this.scriptSteps.length > 0;
    }
}
