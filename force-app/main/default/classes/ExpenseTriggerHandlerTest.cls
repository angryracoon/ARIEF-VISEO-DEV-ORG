/**
 * @class        ExpenseTriggerHandlerTest
 * @description  Tests for ExpenseTrigger / ExpenseTriggerHandler / ExpenseBalanceService.
 *               Verifies FinancialAccount__c.Current_Balance__c is maintained as the
 *               negative sum of linked Expense amounts across insert, bulk, update,
 *               reparent, delete and undelete events.
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
@isTest
private class ExpenseTriggerHandlerTest {

    @TestSetup
    static void setup() {
        TestDataFactory.createCategory('Expense', true);
        TestDataFactory.createFinancialAccounts(2, 'Active', true);
    }

    private static Category__c expenseCategory() {
        return [SELECT Id FROM Category__c WHERE Category_Type__c = 'Expense' LIMIT 1];
    }

    private static List<FinancialAccount__c> accounts() {
        return [SELECT Id, Current_Balance__c FROM FinancialAccount__c ORDER BY Name];
    }

    private static Decimal balanceOf(Id accountId) {
        return [SELECT Current_Balance__c FROM FinancialAccount__c WHERE Id = :accountId].Current_Balance__c;
    }

    @isTest
    static void singleExpenseDeductsBalance() {
        Category__c cat = expenseCategory();
        FinancialAccount__c acc = accounts()[0];

        Test.startTest();
        TestDataFactory.createExpense(cat.Id, acc.Id, 50, true);
        Test.stopTest();

        System.assertEquals(-50, balanceOf(acc.Id), 'Balance should be negative the expense amount.');
    }

    @isTest
    static void bulkExpensesAggregateCorrectly() {
        Category__c cat = expenseCategory();
        FinancialAccount__c acc = accounts()[0];

        Test.startTest();
        TestDataFactory.createExpenses(200, cat.Id, acc.Id, 10, true);
        Test.stopTest();

        System.assertEquals(-2000, balanceOf(acc.Id), '200 x 10 should produce a -2000 balance.');
    }

    @isTest
    static void amountChangeRecalculates() {
        Category__c cat = expenseCategory();
        FinancialAccount__c acc = accounts()[0];
        Expense__c exp = TestDataFactory.createExpense(cat.Id, acc.Id, 50, true);

        Test.startTest();
        exp.Amount__c = 80;
        update exp;
        Test.stopTest();

        System.assertEquals(-80, balanceOf(acc.Id), 'Balance should reflect the updated amount.');
    }

    @isTest
    static void reparentMovesBalanceBetweenAccounts() {
        Category__c cat = expenseCategory();
        List<FinancialAccount__c> accs = accounts();
        FinancialAccount__c accA = accs[0];
        FinancialAccount__c accB = accs[1];
        Expense__c exp = TestDataFactory.createExpense(cat.Id, accA.Id, 30, true);

        Test.startTest();
        exp.Financial_Account__c = accB.Id;
        update exp;
        Test.stopTest();

        System.assertEquals(0, balanceOf(accA.Id), 'Old account balance should reset to zero.');
        System.assertEquals(-30, balanceOf(accB.Id), 'New account should carry the expense.');
    }

    @isTest
    static void deleteRestoresBalance() {
        Category__c cat = expenseCategory();
        FinancialAccount__c acc = accounts()[0];
        Expense__c exp = TestDataFactory.createExpense(cat.Id, acc.Id, 45, true);
        System.assertEquals(-45, balanceOf(acc.Id), 'Precondition: balance deducted.');

        Test.startTest();
        delete exp;
        Test.stopTest();

        System.assertEquals(0, balanceOf(acc.Id), 'Deleting the expense should restore the balance.');
    }

    @isTest
    static void undeleteReappliesBalance() {
        Category__c cat = expenseCategory();
        FinancialAccount__c acc = accounts()[0];
        Expense__c exp = TestDataFactory.createExpense(cat.Id, acc.Id, 25, true);
        delete exp;
        System.assertEquals(0, balanceOf(acc.Id), 'Precondition: balance restored after delete.');

        Test.startTest();
        undelete exp;
        Test.stopTest();

        System.assertEquals(-25, balanceOf(acc.Id), 'Undeleting should re-apply the deduction.');
    }

    @isTest
    static void mixedAccountsAreIndependent() {
        Category__c cat = expenseCategory();
        List<FinancialAccount__c> accs = accounts();
        FinancialAccount__c accA = accs[0];
        FinancialAccount__c accB = accs[1];

        List<Expense__c> toInsert = new List<Expense__c>();
        toInsert.addAll(TestDataFactory.createExpenses(3, cat.Id, accA.Id, 10, false));
        toInsert.addAll(TestDataFactory.createExpenses(2, cat.Id, accB.Id, 20, false));

        Test.startTest();
        insert toInsert;
        Test.stopTest();

        System.assertEquals(-30, balanceOf(accA.Id), 'Account A should total -30.');
        System.assertEquals(-40, balanceOf(accB.Id), 'Account B should total -40.');
    }

    @isTest
    static void expenseWithoutAccountIsIgnored() {
        Category__c cat = expenseCategory();

        Test.startTest();
        TestDataFactory.createExpense(cat.Id, null, 99, true);
        Test.stopTest();

        for (FinancialAccount__c acc : accounts()) {
            Decimal bal = acc.Current_Balance__c;
            System.assert(bal == null || bal == 0, 'Unlinked expense must not affect any account.');
        }
    }
}
