import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import uploadReceipt from '@salesforce/apex/ReceiptScanController.uploadReceipt';
import processReceipt from '@salesforce/apex/ReceiptScanController.processReceipt';
import matchCategory from '@salesforce/apex/ReceiptScanController.matchCategory';
import createExpenseFromReceipt from '@salesforce/apex/ReceiptScanController.createExpenseFromReceipt';
import getActiveFinancialAccounts from '@salesforce/apex/ReceiptScanController.getActiveFinancialAccounts';

const STEP_CAPTURE = 'capture';
const STEP_REVIEW = 'review';
const STEP_CONFIRM = 'confirm';
const STEP_SUCCESS = 'success';

/**
 * receiptScanWorkflow
 * Guided, step-based workflow: capture -> review -> confirm -> success.
 * Uploads a receipt image, runs AI extraction, lets the user review and correct
 * the values, selects a Financial Account, and creates an Expense via the
 * standard insert path so existing Validation Rules and budget automation fire.
 */
export default class ReceiptScanWorkflow extends NavigationMixin(LightningElement) {
    step = STEP_CAPTURE;
    isLoading = false;

    // Capture state
    fileName;
    previewUrl;
    base64Data;
    contentType;
    contentVersionId;

    // Review state
    @track form = {
        merchant: '',
        transactionDate: '',
        amount: null,
        categoryId: '',
        financialAccountId: '',
        notes: ''
    };
    confidenceScore;
    categoryName;

    financialAccountOptions = [];
    createdExpenseId;

    /** Loads active Financial Accounts for the selection combobox. */
    @wire(getActiveFinancialAccounts)
    wiredAccounts({ data, error }) {
        if (data) {
            this.financialAccountOptions = data.map((acc) => ({
                label: acc.Name,
                value: acc.Id
            }));
        } else if (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        }
    }

    // ─── Step helpers ────────────────────────────────────────────────────
    get isCapture() {
        return this.step === STEP_CAPTURE;
    }
    get isReview() {
        return this.step === STEP_REVIEW;
    }
    get isConfirm() {
        return this.step === STEP_CONFIRM;
    }
    get isSuccess() {
        return this.step === STEP_SUCCESS;
    }
    get scanDisabled() {
        return !this.base64Data || this.isLoading;
    }
    get hasConfidence() {
        return this.confidenceScore !== null && this.confidenceScore !== undefined;
    }
    get confidencePercent() {
        return this.hasConfidence ? Math.round(this.confidenceScore * 100) + '%' : '';
    }
    get confidenceClass() {
        if (!this.hasConfidence) {
            return 'slds-badge';
        }
        if (this.confidenceScore >= 0.8) {
            return 'slds-badge slds-theme_success';
        }
        if (this.confidenceScore >= 0.5) {
            return 'slds-badge slds-theme_warning';
        }
        return 'slds-badge slds-theme_error';
    }
    get selectedAccountLabel() {
        const match = this.financialAccountOptions.find(
            (o) => o.value === this.form.financialAccountId
        );
        return match ? match.label : 'None';
    }

    // ─── Capture step ────────────────────────────────────────────────────
    /** Reads the selected image file into a base64 string and a preview URL. */
    handleFileChange(event) {
        const file = event.target.files && event.target.files[0];
        if (!file) {
            return;
        }
        this.fileName = file.name;
        this.contentType = file.type;
        const reader = new FileReader();
        reader.onload = () => {
            this.previewUrl = reader.result;
            // Strip the "data:<mime>;base64," prefix.
            const commaIndex = reader.result.indexOf(',');
            this.base64Data = commaIndex > -1 ? reader.result.substring(commaIndex + 1) : reader.result;
        };
        reader.onerror = () => {
            this.showToast('Error', 'Could not read the selected file.', 'error');
        };
        reader.readAsDataURL(file);
    }

    /** Uploads the receipt, runs extraction, and advances to the review step. */
    async handleUploadAndScan() {
        if (!this.base64Data) {
            return;
        }
        this.isLoading = true;
        try {
            this.contentVersionId = await uploadReceipt({
                base64Data: this.base64Data,
                filename: this.fileName,
                contentType: this.contentType
            });

            const result = await processReceipt({ contentVersionId: this.contentVersionId });
            if (result && result.success) {
                await this.applyExtraction(result);
            } else {
                const message = result && result.errorMessage ? result.errorMessage : 'AI extraction was unsuccessful.';
                this.showToast('Scan incomplete', message + ' You can enter the details manually.', 'warning');
            }
            // Always proceed to review; fields are editable whether or not extraction succeeded.
            this.step = STEP_REVIEW;
        } catch (error) {
            this.showToast('Error', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    /** Maps an extraction result onto the editable review form. */
    async applyExtraction(result) {
        this.form = {
            ...this.form,
            merchant: result.merchantName || '',
            transactionDate: result.expenseDate || '',
            amount: result.totalAmount !== undefined ? result.totalAmount : null,
            notes: result.merchantName ? 'Created from scanned receipt: ' + result.merchantName : 'Created from scanned receipt'
        };
        this.confidenceScore = result.confidenceScore;
        this.categoryName = result.suggestedCategoryName;

        if (result.suggestedCategoryName) {
            try {
                const category = await matchCategory({ categoryName: result.suggestedCategoryName });
                if (category) {
                    this.form = { ...this.form, categoryId: category.Id };
                    this.categoryName = category.Name;
                }
            } catch (error) {
                // Non-fatal: leave the category empty for manual selection.
                this.categoryName = result.suggestedCategoryName;
            }
        }
    }

    // ─── Review step ─────────────────────────────────────────────────────
    handleMerchantChange(event) {
        this.form = { ...this.form, merchant: event.target.value };
    }
    handleDateChange(event) {
        this.form = { ...this.form, transactionDate: event.target.value };
    }
    handleAmountChange(event) {
        this.form = { ...this.form, amount: event.target.value };
    }
    handleNotesChange(event) {
        this.form = { ...this.form, notes: event.target.value };
    }
    handleAccountChange(event) {
        this.form = { ...this.form, financialAccountId: event.detail.value };
    }
    handleCategoryChange(event) {
        this.form = { ...this.form, categoryId: event.detail.recordId };
    }

    /** Validates required fields and advances to the confirm step. */
    handleReviewNext() {
        if (!this.form.amount || Number(this.form.amount) <= 0) {
            this.showToast('Missing amount', 'Enter an amount greater than zero.', 'warning');
            return;
        }
        this.step = STEP_CONFIRM;
    }

    handleBackToCapture() {
        this.step = STEP_CAPTURE;
    }
    handleBackToReview() {
        this.step = STEP_REVIEW;
    }

    // ─── Confirm step ────────────────────────────────────────────────────
    /** Creates the Expense via the controller and advances to success. */
    async handleCreateExpense() {
        this.isLoading = true;
        try {
            this.createdExpenseId = await createExpenseFromReceipt({
                expenseData: {
                    merchant: this.form.merchant,
                    amount: this.form.amount,
                    transactionDate: this.form.transactionDate,
                    categoryId: this.form.categoryId,
                    financialAccountId: this.form.financialAccountId,
                    notes: this.form.notes,
                    transactionType: 'Expense'
                },
                contentVersionId: this.contentVersionId
            });
            this.step = STEP_SUCCESS;
            this.showToast('Success', 'Expense created successfully.', 'success');
        } catch (error) {
            // Preserve the form so the user can correct and retry.
            this.showToast('Could not create expense', this.reduceError(error), 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ─── Success step ────────────────────────────────────────────────────
    /** Navigates to the newly created Expense record. */
    handleViewExpense() {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.createdExpenseId,
                objectApiName: 'Expense__c',
                actionName: 'view'
            }
        });
        this.dispatchClose();
    }

    /** Resets the workflow to scan another receipt. */
    handleStartOver() {
        this.resetState();
    }

    /** Cancels and notifies the parent to close the workflow. */
    handleCancel() {
        this.dispatchClose();
    }

    // ─── Utilities ───────────────────────────────────────────────────────
    dispatchClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    resetState() {
        this.step = STEP_CAPTURE;
        this.fileName = undefined;
        this.previewUrl = undefined;
        this.base64Data = undefined;
        this.contentType = undefined;
        this.contentVersionId = undefined;
        this.confidenceScore = undefined;
        this.categoryName = undefined;
        this.createdExpenseId = undefined;
        this.form = {
            merchant: '',
            transactionDate: '',
            amount: null,
            categoryId: '',
            financialAccountId: '',
            notes: ''
        };
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    reduceError(error) {
        if (Array.isArray(error.body)) {
            return error.body.map((e) => e.message).join(', ');
        }
        if (error.body && typeof error.body.message === 'string') {
            return error.body.message;
        }
        if (typeof error.message === 'string') {
            return error.message;
        }
        return 'An unexpected error occurred.';
    }
}
