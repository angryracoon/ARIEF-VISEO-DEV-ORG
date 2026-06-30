/**
 * @class        TestDataFactory
 * @description  Centralized factory for creating test data with sensible defaults.
 *               All methods accept a doInsert flag for flexibility.
 *               Single-record methods delegate to their bulk counterparts.
 * @author       Arief Gunawan
 * @date         2026-06-26
 */
@isTest
public class TestDataFactory {

    // ─── Accounts ─────────────────────────────────────────────────────────

    public static List<Account> createAccounts(Integer count, Boolean doInsert) {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i,
                BillingCity = 'San Francisco',
                BillingState = 'CA',
                BillingCountry = 'USA',
                Industry = 'Technology',
                Type = 'Customer'
            ));
        }
        if (doInsert) insert accounts;
        return accounts;
    }

    public static Account createAccount(Boolean doInsert) {
        return createAccounts(1, doInsert)[0];
    }

    // ─── Contacts ─────────────────────────────────────────────────────────

    public static List<Contact> createContacts(List<Account> accounts, Integer countPerAccount, Boolean doInsert) {
        List<Contact> contacts = new List<Contact>();
        Integer idx = 0;
        for (Account acc : accounts) {
            for (Integer i = 0; i < countPerAccount; i++) {
                contacts.add(new Contact(
                    FirstName = 'Test',
                    LastName = 'Contact ' + idx,
                    Email = 'test.contact' + idx + '@example.com',
                    AccountId = acc.Id
                ));
                idx++;
            }
        }
        if (doInsert) insert contacts;
        return contacts;
    }

    // ─── Opportunities (with Account) ─────────────────────────────────────

    public static List<Opportunity> createOpportunities(List<Account> accounts, Integer countPerAccount, Boolean doInsert) {
        List<Opportunity> opps = new List<Opportunity>();
        Integer idx = 0;
        for (Account acc : accounts) {
            for (Integer i = 0; i < countPerAccount; i++) {
                opps.add(new Opportunity(
                    Name = 'Test Opportunity ' + idx,
                    AccountId = acc.Id,
                    StageName = 'Prospecting',
                    CloseDate = Date.today().addDays(30),
                    Amount = 10000 + (idx * 1000)
                ));
                idx++;
            }
        }
        if (doInsert) insert opps;
        return opps;
    }

    // ─── Opportunities (standalone) ───────────────────────────────────────

    public static List<Opportunity> createOpportunities(Integer count, String stageName, Date closeDate, Boolean doInsert) {
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < count; i++) {
            opps.add(new Opportunity(
                Name = 'Test Opportunity ' + i,
                StageName = stageName,
                CloseDate = closeDate
            ));
        }
        if (doInsert) insert opps;
        return opps;
    }

    public static Opportunity createOpportunity(String stageName, Date closeDate, Boolean doInsert) {
        return createOpportunities(1, stageName, closeDate, doInsert)[0];
    }

    // ─── Categories ───────────────────────────────────────────────────────

    public static List<Category__c> createCategories(Integer count, String categoryType, Boolean doInsert) {
        List<Category__c> categories = new List<Category__c>();
        for (Integer i = 0; i < count; i++) {
            categories.add(new Category__c(
                Name = 'Test Category ' + categoryType + ' ' + i,
                Category_Type__c = categoryType,
                Active__c = true
            ));
        }
        if (doInsert) insert categories;
        return categories;
    }

    public static Category__c createCategory(String categoryType, Boolean doInsert) {
        return createCategories(1, categoryType, doInsert)[0];
    }

    // ─── Financial Accounts ───────────────────────────────────────────────

    public static List<FinancialAccount__c> createFinancialAccounts(Integer count, String status, Boolean doInsert) {
        List<FinancialAccount__c> accounts = new List<FinancialAccount__c>();
        for (Integer i = 0; i < count; i++) {
            accounts.add(new FinancialAccount__c(
                Name = 'Test Account ' + i,
                Account_Type__c = 'Cash',
                Status__c = status
            ));
        }
        if (doInsert) insert accounts;
        return accounts;
    }

    public static FinancialAccount__c createFinancialAccount(String status, Boolean doInsert) {
        return createFinancialAccounts(1, status, doInsert)[0];
    }

    // ─── Expenses ─────────────────────────────────────────────────────────

    public static List<Expense__c> createExpenses(
        Integer count,
        Id categoryId,
        Id financialAccountId,
        Decimal amount,
        Boolean doInsert
    ) {
        List<Expense__c> expenses = new List<Expense__c>();
        for (Integer i = 0; i < count; i++) {
            expenses.add(new Expense__c(
                Transaction_Type__c = 'Expense',
                Amount__c = amount,
                Transaction_Date__c = Date.today(),
                Category__c = categoryId,
                Financial_Account__c = financialAccountId,
                Merchant__c = 'Test Merchant ' + i
            ));
        }
        if (doInsert) insert expenses;
        return expenses;
    }

    public static Expense__c createExpense(
        Id categoryId,
        Id financialAccountId,
        Decimal amount,
        Boolean doInsert
    ) {
        return createExpenses(1, categoryId, financialAccountId, amount, doInsert)[0];
    }

    // ─── Users ────────────────────────────────────────────────────────────

    public static User createUser(String profileName, Boolean doInsert) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        String uniqueKey = String.valueOf(DateTime.now().getTime());

        User u = new User(
            FirstName = 'Test',
            LastName = 'User ' + uniqueKey,
            Email = 'testuser' + uniqueKey + '@example.com',
            Username = 'testuser' + uniqueKey + '@example.com.test',
            Alias = 'tuser',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        if (doInsert) insert u;
        return u;
    }
}