/**
 * @class        ReceiptScanController
 * @description  Aura-enabled controller backing the receiptScanWorkflow LWC. Handles
 *               receipt upload (ContentVersion), AI extraction (via the swappable
 *               ReceiptAiService), Financial Account and Category lookups, and
 *               creation of an Expense__c from the reviewed values.
 *
 *               Expense creation uses a standard insert so existing Validation Rules
 *               and the Expense_Update_Budget_Spending flow continue to fire — no
 *               business logic is duplicated here.
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
public with sharing class ReceiptScanController {

    /** Default transaction type applied when the UI does not supply one. */
    private static final String DEFAULT_TRANSACTION_TYPE = 'Expense';

    /**
     * @description  Persists an uploaded receipt image as a ContentVersion.
     * @param        base64Data   Base64-encoded file content.
     * @param        filename     Original file name.
     * @param        contentType  MIME type (currently informational).
     * @return       The Id of the created ContentVersion.
     */
    @AuraEnabled
    public static Id uploadReceipt(String base64Data, String filename, String contentType) {
        if (String.isBlank(base64Data)) {
            throw new AuraHandledException('No file data was provided.');
        }
        try {
            String safeName = String.isBlank(filename) ? 'Receipt' : filename;
            ContentVersion cv = new ContentVersion(
                Title = safeName,
                PathOnClient = safeName,
                VersionData = EncodingUtil.base64Decode(base64Data),
                Origin = 'H'
            );
            Database.insert(cv, AccessLevel.USER_MODE);
            return cv.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Could not upload the receipt: ' + e.getMessage());
        }
    }

    /**
     * @description  Loads the stored receipt image and runs AI extraction on it.
     * @param        contentVersionId  Id of the ContentVersion to process.
     * @return       The extraction result (success or structured failure).
     */
    @AuraEnabled
    public static ReceiptExtractionResult processReceipt(String contentVersionId) {
        if (String.isBlank(contentVersionId)) {
            return ReceiptExtractionResult.failure('No receipt was supplied for processing.');
        }
        try {
            List<ContentVersion> versions = [
                SELECT VersionData, FileExtension
                FROM ContentVersion
                WHERE Id = :contentVersionId
                WITH USER_MODE
                LIMIT 1
            ];
            if (versions.isEmpty()) {
                return ReceiptExtractionResult.failure('The uploaded receipt could not be found.');
            }

            ContentVersion cv = versions[0];
            String base64Image = EncodingUtil.base64Encode(cv.VersionData);
            String mediaType = toMediaType(cv.FileExtension);

            return ReceiptAiServiceFactory.getInstance().extractFromReceipt(base64Image, mediaType);
        } catch (Exception e) {
            return ReceiptExtractionResult.failure('Receipt processing failed: ' + e.getMessage());
        }
    }

    /**
     * @description  Returns the active Financial Accounts available for selection.
     * @return       Active FinancialAccount__c records (Id, Name, type, balance).
     */
    @AuraEnabled(cacheable=true)
    public static List<FinancialAccount__c> getActiveFinancialAccounts() {
        return [
            SELECT Id, Name, Account_Type__c, Current_Balance__c
            FROM FinancialAccount__c
            WHERE Status__c = 'Active'
            WITH USER_MODE
            ORDER BY Name
        ];
    }

    /**
     * @description  Finds the best matching existing Category by name. Never creates
     *               a Category. Prefers a case-insensitive exact match, otherwise the
     *               first partial (LIKE) match.
     * @param        categoryName  Suggested category name from extraction.
     * @return       The matched Category__c (Id, Name) or null when none match.
     */
    @AuraEnabled(cacheable=true)
    public static Category__c matchCategory(String categoryName) {
        if (String.isBlank(categoryName)) {
            return null;
        }
        String term = '%' + categoryName.trim() + '%';
        List<Category__c> candidates = [
            SELECT Id, Name
            FROM Category__c
            WHERE Name LIKE :term
            WITH USER_MODE
            ORDER BY Name
            LIMIT 50
        ];
        if (candidates.isEmpty()) {
            return null;
        }
        for (Category__c candidate : candidates) {
            if (candidate.Name != null && candidate.Name.equalsIgnoreCase(categoryName.trim())) {
                return candidate;
            }
        }
        return candidates[0];
    }

    /**
     * @description  Creates an Expense__c from reviewed receipt values via a standard
     *               insert (so VRs and the budget flow fire), then attaches the
     *               receipt file to the new record.
     * @param        expenseData       Map of field values from the UI. Recognized keys:
     *                                  merchant, amount, transactionDate, transactionType,
     *                                  categoryId, financialAccountId, paymentMethod, notes.
     * @param        contentVersionId  Id of the receipt ContentVersion to attach (optional).
     * @return       The Id of the created Expense__c.
     */
    @AuraEnabled
    public static Id createExpenseFromReceipt(Map<String, Object> expenseData, String contentVersionId) {
        if (expenseData == null || expenseData.isEmpty()) {
            throw new AuraHandledException('No expense data was provided.');
        }
        try {
            Expense__c expense = buildExpense(expenseData);
            Database.insert(expense, AccessLevel.USER_MODE);

            if (String.isNotBlank(contentVersionId)) {
                attachReceipt(expense.Id, contentVersionId);
            }
            return expense.Id;
        } catch (DmlException e) {
            // Surface the first (typically Validation Rule) message to the UI.
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Could not create the expense: ' + e.getMessage());
        }
    }

    /**
     * @description  Maps the UI value map onto a new Expense__c record.
     * @param        data  Field values from the UI.
     * @return       An unsaved Expense__c.
     */
    private static Expense__c buildExpense(Map<String, Object> data) {
        Expense__c expense = new Expense__c();
        expense.Merchant__c = asString(data.get('merchant'));
        expense.Amount__c = asDecimal(data.get('amount'));
        expense.Transaction_Date__c = asDate(data.get('transactionDate'));
        expense.Notes__c = asString(data.get('notes'));
        expense.Payment_Method__c = asString(data.get('paymentMethod'));

        String txnType = asString(data.get('transactionType'));
        expense.Transaction_Type__c = String.isBlank(txnType) ? DEFAULT_TRANSACTION_TYPE : txnType;

        String categoryId = asString(data.get('categoryId'));
        if (String.isNotBlank(categoryId)) {
            expense.Category__c = (Id) categoryId;
        }
        String financialAccountId = asString(data.get('financialAccountId'));
        if (String.isNotBlank(financialAccountId)) {
            expense.Financial_Account__c = (Id) financialAccountId;
        }
        return expense;
    }

    /**
     * @description  Links an uploaded receipt ContentVersion to the new Expense.
     * @param        expenseId         Expense record to attach to.
     * @param        contentVersionId  ContentVersion whose document is linked.
     */
    private static void attachReceipt(Id expenseId, String contentVersionId) {
        List<ContentVersion> versions = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :contentVersionId
            WITH USER_MODE
            LIMIT 1
        ];
        if (versions.isEmpty()) {
            return;
        }
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = versions[0].ContentDocumentId,
            LinkedEntityId = expenseId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        Database.insert(link, AccessLevel.USER_MODE);
    }

    /**
     * @description  Maps a file extension to an image MIME type, defaulting to image/jpeg.
     * @param        extension  File extension (e.g. png, jpg).
     * @return       A MIME type string.
     */
    private static String toMediaType(String extension) {
        if (String.isBlank(extension)) {
            return 'image/jpeg';
        }
        String ext = extension.toLowerCase();
        if (ext == 'jpg' || ext == 'jpeg') {
            return 'image/jpeg';
        }
        if (ext == 'png') {
            return 'image/png';
        }
        if (ext == 'gif') {
            return 'image/gif';
        }
        if (ext == 'webp') {
            return 'image/webp';
        }
        return 'image/jpeg';
    }

    /**
     * @description  Null-safe String conversion.
     * @param        value  Raw value.
     * @return       String value or null.
     */
    private static String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    /**
     * @description  Null-safe Decimal conversion.
     * @param        value  Raw value.
     * @return       Decimal value or null.
     */
    private static Decimal asDecimal(Object value) {
        if (value == null || String.isBlank(String.valueOf(value))) {
            return null;
        }
        return Decimal.valueOf(String.valueOf(value));
    }

    /**
     * @description  Null-safe ISO Date conversion.
     * @param        value  Raw value (yyyy-MM-dd).
     * @return       Date value or null.
     */
    private static Date asDate(Object value) {
        if (value == null || String.isBlank(String.valueOf(value))) {
            return null;
        }
        return Date.valueOf(String.valueOf(value));
    }
}
