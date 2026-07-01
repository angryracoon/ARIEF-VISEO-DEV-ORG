@IsTest
private class CategoryTriggerHandlerTest {

    // ──────────────────────────────────────────────────────────────────────────
    // Helper factory methods
    // ──────────────────────────────────────────────────────────────────────────

    private static Category__c makeCategory(String name, String type) {
        return new Category__c(
            Name             = name,
            Category_Type__c = type,
            Active__c        = true
        );
    }

    private static Expense__c makeExpense(Id categoryId) {
        return new Expense__c(
            Category__c       = categoryId,
            Amount__c         = 100,
            Transaction_Date__c = Date.today(),
            Transaction_Type__c = 'Expense'
        );
    }

    private static Budget__c makeBudget(Id categoryId) {
        return new Budget__c(
            Category__c    = categoryId,
            Month__c       = Date.today().toStartOfMonth(),
            Budget_Amount__c = 500
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 1: Category with no children — deletion must succeed
    // ──────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testPositive_NoChildren_DeleteSucceeds() {
        Category__c cat = makeCategory('Test Category No Children', 'Expense');
        insert cat;

        Test.startTest();
        Database.DeleteResult result = Database.delete(cat, false);
        Test.stopTest();

        Assert.isTrue(result.isSuccess(), 'Category with no children should be deletable');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 2: Category with Expense child — deletion must be blocked
    // ──────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testNegative_HasExpenseChild_DeleteBlocked() {
        Category__c cat = makeCategory('Test Category With Expense', 'Expense');
        insert cat;

        Expense__c exp = makeExpense(cat.Id);
        insert exp;

        Test.startTest();
        Database.DeleteResult result = Database.delete(cat, false);
        Test.stopTest();

        Assert.isFalse(result.isSuccess(), 'Category with Expense child should not be deletable');
        Assert.isTrue(
            result.getErrors()[0].getMessage().contains('Expense or Budget records'),
            'Error message should mention Expense or Budget records'
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 3: Category with Budget child — deletion must be blocked
    // ──────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testNegative_HasBudgetChild_DeleteBlocked() {
        Category__c cat = makeCategory('Test Category With Budget', 'Expense');
        insert cat;

        Budget__c bud = makeBudget(cat.Id);
        insert bud;

        Test.startTest();
        Database.DeleteResult result = Database.delete(cat, false);
        Test.stopTest();

        Assert.isFalse(result.isSuccess(), 'Category with Budget child should not be deletable');
        Assert.isTrue(
            result.getErrors()[0].getMessage().contains('Expense or Budget records'),
            'Error message should mention Expense or Budget records'
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 4: Category with both Expense and Budget children — deletion must be blocked
    // ──────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testNegative_HasBothChildren_DeleteBlocked() {
        Category__c cat = makeCategory('Test Category With Both', 'Expense');
        insert cat;

        insert makeExpense(cat.Id);
        insert makeBudget(cat.Id);

        Test.startTest();
        Database.DeleteResult result = Database.delete(cat, false);
        Test.stopTest();

        Assert.isFalse(result.isSuccess(), 'Category with both Expense and Budget children should not be deletable');
        Assert.isTrue(
            result.getErrors()[0].getMessage().contains('Expense or Budget records'),
            'Error message should mention Expense or Budget records'
        );
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 5: Bulk — 100 blocked + 100 allowed categories
    // ──────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testBulk_MixedCategories_OnlyBlockedAreRejected() {
        List<Category__c> blockedCats = new List<Category__c>();
        List<Category__c> allowedCats = new List<Category__c>();

        for (Integer i = 0; i < 100; i++) {
            blockedCats.add(makeCategory('Blocked Cat ' + i, 'Expense'));
            allowedCats.add(makeCategory('Allowed Cat ' + i, 'Expense'));
        }
        insert blockedCats;
        insert allowedCats;

        List<Expense__c> expenses = new List<Expense__c>();
        for (Category__c cat : blockedCats) {
            expenses.add(makeExpense(cat.Id));
        }
        insert expenses;

        List<Category__c> allCats = new List<Category__c>();
        allCats.addAll(blockedCats);
        allCats.addAll(allowedCats);

        Test.startTest();
        List<Database.DeleteResult> results = Database.delete(allCats, false);
        Test.stopTest();

        Integer successCount = 0;
        Integer failureCount = 0;
        for (Database.DeleteResult dr : results) {
            if (dr.isSuccess()) {
                successCount++;
            } else {
                failureCount++;
            }
        }

        Assert.areEqual(100, successCount, 'Exactly 100 allowed categories should be deleted successfully');
        Assert.areEqual(100, failureCount, 'Exactly 100 blocked categories should fail deletion');
    }

    // ──────────────────────────────────────────────────────────────────────────
    // Test 6: Unit test — direct call to @TestVisible private helper
    // ──────────────────────────────────────────────────────────────────────────

    @IsTest
    static void testUnit_GetCategoriesWithChildren_DirectCall() {
        Category__c catWithExpense = makeCategory('Cat With Expense', 'Expense');
        Category__c catWithBudget  = makeCategory('Cat With Budget', 'Expense');
        Category__c catEmpty       = makeCategory('Cat Empty', 'Expense');
        insert new List<Category__c>{ catWithExpense, catWithBudget, catEmpty };

        insert makeExpense(catWithExpense.Id);
        insert makeBudget(catWithBudget.Id);

        Set<Id> allIds = new Set<Id>{
            catWithExpense.Id,
            catWithBudget.Id,
            catEmpty.Id
        };

        Test.startTest();
        CategoryTriggerHandler handler = new CategoryTriggerHandler();
        Set<Id> blocked = handler.getCategoriesWithChildren(allIds);
        Test.stopTest();

        Assert.areEqual(2, blocked.size(), 'Two categories should be blocked (one has Expense, one has Budget)');
        Assert.isTrue(blocked.contains(catWithExpense.Id), 'Category with Expense child should be in blocked set');
        Assert.isTrue(blocked.contains(catWithBudget.Id),  'Category with Budget child should be in blocked set');
        Assert.isFalse(blocked.contains(catEmpty.Id),      'Empty category should NOT be in blocked set');
    }
}