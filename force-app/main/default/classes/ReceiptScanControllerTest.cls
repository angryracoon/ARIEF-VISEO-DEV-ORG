/**
 * @class        ReceiptScanControllerTest
 * @description  Tests for ReceiptScanController: receipt upload, AI processing via
 *               the mock provider, Financial Account retrieval, Category matching
 *               (hit and miss), and Expense creation (including Validation Rule
 *               enforcement and receipt attachment).
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
@isTest
private class ReceiptScanControllerTest {

    @TestSetup
    static void setup() {
        insert new Category__c(Name = 'Groceries', Category_Type__c = 'Expense', Active__c = true);
        TestDataFactory.createFinancialAccount('Active', true);
        TestDataFactory.createFinancialAccount('Inactive', true);
    }

    private static String sampleBase64() {
        return EncodingUtil.base64Encode(Blob.valueOf('fake-image-bytes'));
    }

    @isTest
    static void uploadReceiptCreatesContentVersion() {
        Test.startTest();
        Id cvId = ReceiptScanController.uploadReceipt(sampleBase64(), 'receipt.jpg', 'image/jpeg');
        Test.stopTest();

        System.assertNotEquals(null, cvId, 'A ContentVersion Id should be returned.');
        ContentVersion cv = [SELECT Title FROM ContentVersion WHERE Id = :cvId];
        System.assertEquals('receipt.jpg', cv.Title, 'Title should match the file name.');
    }

    @isTest
    static void uploadReceiptBlankThrows() {
        Test.startTest();
        try {
            ReceiptScanController.uploadReceipt('', 'r.jpg', 'image/jpeg');
            System.assert(false, 'Expected an exception for blank data.');
        } catch (AuraHandledException e) {
            System.assert(true, 'Exception thrown as expected.');
        }
        Test.stopTest();
    }

    @isTest
    static void processReceiptReturnsMockExtraction() {
        Id cvId = ReceiptScanController.uploadReceipt(sampleBase64(), 'receipt.jpg', 'image/jpeg');

        Test.startTest();
        ReceiptExtractionResult result = ReceiptScanController.processReceipt(cvId);
        Test.stopTest();

        System.assertEquals(true, result.success, 'Mock provider should return success.');
        System.assertEquals('FairPrice Finest', result.merchantName, 'Mock merchant expected.');
        System.assertNotEquals(null, result.totalAmount, 'Mock amount expected.');
    }

    @isTest
    static void processReceiptMissingIdReturnsFailure() {
        Test.startTest();
        ReceiptExtractionResult result = ReceiptScanController.processReceipt(null);
        Test.stopTest();

        System.assertEquals(false, result.success, 'Null id should produce a failure result.');
    }

    @isTest
    static void getActiveFinancialAccountsReturnsOnlyActive() {
        Test.startTest();
        List<FinancialAccount__c> accounts = ReceiptScanController.getActiveFinancialAccounts();
        Test.stopTest();

        System.assertEquals(1, accounts.size(), 'Only the active account should be returned.');
    }

    @isTest
    static void matchCategoryFindsExactMatch() {
        Test.startTest();
        Category__c match = ReceiptScanController.matchCategory('Groceries');
        Test.stopTest();

        System.assertNotEquals(null, match, 'An exact category match should be found.');
        System.assertEquals('Groceries', match.Name, 'Matched category name should be Groceries.');
    }

    @isTest
    static void matchCategoryReturnsNullOnMiss() {
        Test.startTest();
        Category__c match = ReceiptScanController.matchCategory('Nonexistent Category');
        Test.stopTest();

        System.assertEquals(null, match, 'No match should return null.');
    }

    @isTest
    static void matchCategoryBlankReturnsNull() {
        System.assertEquals(null, ReceiptScanController.matchCategory('   '), 'Blank input returns null.');
    }

    @isTest
    static void createExpenseFromReceiptSucceedsAndAttaches() {
        Category__c cat = [SELECT Id FROM Category__c LIMIT 1];
        FinancialAccount__c acc = [SELECT Id FROM FinancialAccount__c WHERE Status__c = 'Active' LIMIT 1];
        Id cvId = ReceiptScanController.uploadReceipt(sampleBase64(), 'receipt.jpg', 'image/jpeg');

        Map<String, Object> data = new Map<String, Object>{
            'merchant' => 'FairPrice',
            'amount' => 42.50,
            'transactionDate' => String.valueOf(Date.today()),
            'categoryId' => cat.Id,
            'financialAccountId' => acc.Id,
            'transactionType' => 'Expense',
            'notes' => 'From receipt'
        };

        Test.startTest();
        Id expenseId = ReceiptScanController.createExpenseFromReceipt(data, cvId);
        Test.stopTest();

        System.assertNotEquals(null, expenseId, 'Expense should be created.');

        Expense__c created = [SELECT Amount__c, Financial_Account__c FROM Expense__c WHERE Id = :expenseId];
        System.assertEquals(42.50, created.Amount__c, 'Amount should persist.');
        System.assertEquals(acc.Id, created.Financial_Account__c, 'Financial account should be linked.');

        Integer links = [SELECT COUNT() FROM ContentDocumentLink WHERE LinkedEntityId = :expenseId];
        System.assertEquals(1, links, 'Receipt should be attached to the expense.');

        Decimal bal = [SELECT Current_Balance__c FROM FinancialAccount__c WHERE Id = :acc.Id].Current_Balance__c;
        System.assertEquals(-42.50, bal, 'Balance trigger should fire on standard insert.');
    }

    @isTest
    static void createExpenseValidationRuleFires() {
        FinancialAccount__c acc = [SELECT Id FROM FinancialAccount__c WHERE Status__c = 'Active' LIMIT 1];
        // Missing categoryId -> Category_Is_Required validation rule should fire.
        Map<String, Object> data = new Map<String, Object>{
            'merchant' => 'NoCategory',
            'amount' => 10,
            'transactionDate' => String.valueOf(Date.today()),
            'financialAccountId' => acc.Id,
            'transactionType' => 'Expense'
        };

        Test.startTest();
        try {
            ReceiptScanController.createExpenseFromReceipt(data, null);
            System.assert(false, 'Expected a validation rule exception.');
        } catch (AuraHandledException e) {
            System.assert(true, 'Validation rule surfaced as expected.');
        }
        Test.stopTest();
    }

    @isTest
    static void createExpenseEmptyDataThrows() {
        Test.startTest();
        try {
            ReceiptScanController.createExpenseFromReceipt(new Map<String, Object>(), null);
            System.assert(false, 'Expected an exception for empty data.');
        } catch (AuraHandledException e) {
            System.assert(true, 'Exception thrown as expected.');
        }
        Test.stopTest();
    }
}
