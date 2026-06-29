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