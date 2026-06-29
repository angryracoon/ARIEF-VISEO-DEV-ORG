import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

/**
 * expenseCreationPanel
 * Home-page entry point for creating an expense. Offers a manual create path
 * (navigates to the standard New Expense page) and an AI-assisted "Scan Receipt"
 * path that reveals the guided receiptScanWorkflow inline.
 */
export default class ExpenseCreationPanel extends NavigationMixin(LightningElement) {
    showScanner = false;

    /** Navigates to the standard New Expense record page. */
    handleCreateManually() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: {
                objectApiName: 'Expense__c',
                actionName: 'new'
            }
        });
    }

    /** Reveals the inline receipt-scan workflow. */
    handleScanReceipt() {
        this.showScanner = true;
    }

    /** Hides the scanner when the child workflow signals completion or cancel. */
    handleScannerClose() {
        this.showScanner = false;
    }
}
