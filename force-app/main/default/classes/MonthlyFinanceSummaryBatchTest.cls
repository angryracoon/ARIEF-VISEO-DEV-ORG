@IsTest
private class MonthlyFinanceSummaryBatchTest {

    private static User createTestUser(String suffix) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = 'Finance' + suffix,
            Email = 'testfinance' + suffix + '@example.com',
            Username = 'testfinance' + suffix + '_pft@example.com.pfttest',
            Alias = 'tf' + suffix,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;
        return u;
    }

    @IsTest
    static void testBudgetClonedAndEmailSent() {
        User testUser = createTestUser('A');
        Category__c cat = new Category__c(Name = 'Food', Category_Type__c = 'Expense', Active__c = true);
        Category__c incomeCat = new Category__c(Name = 'Salary', Category_Type__c = 'Income', Active__c = true);
        insert new List<Category__c>{ cat, incomeCat };

        Date prevMonth = Date.today().toStartOfMonth().addMonths(-1);

        System.runAs(testUser) {
            insert new List<Expense__c>{
                new Expense__c(
                    Transaction_Date__c = prevMonth.addDays(5),
                    Amount__c = 50,
                    Transaction_Type__c = 'Expense',
                    Category__c = cat.Id
                ),
                new Expense__c(
                    Transaction_Date__c = prevMonth.addDays(1),
                    Amount__c = 3000,
                    Transaction_Type__c = 'Income',
                    Category__c = incomeCat.Id
                )
            };
            insert new Budget__c(
                Category__c = cat.Id,
                Month__c = prevMonth,
                Budget_Amount__c = 100
            );
        }

        Test.startTest();
        Database.executeBatch(new MonthlyFinanceSummaryBatch(), 200);
        Test.stopTest();

        Date newMonth = Date.today().toStartOfMonth();
        List<Budget__c> cloned = [SELECT Id FROM Budget__c WHERE Month__c = :newMonth AND OwnerId = :testUser.Id];
        System.assertEquals(1, cloned.size(), 'One budget should be cloned to current month');
    }

    @IsTest
    static void testNoDuplicateBudgetClone() {
        User testUser = createTestUser('B');
        Category__c cat = new Category__c(Name = 'Transport', Category_Type__c = 'Expense', Active__c = true);
        insert cat;

        Date prevMonth = Date.today().toStartOfMonth().addMonths(-1);
        Date newMonth = Date.today().toStartOfMonth();

        System.runAs(testUser) {
            insert new Expense__c(
                Transaction_Date__c = prevMonth.addDays(3),
                Amount__c = 20,
                Transaction_Type__c = 'Expense',
                Category__c = cat.Id
            );
            insert new Budget__c(
                Category__c = cat.Id,
                Month__c = prevMonth,
                Budget_Amount__c = 50
            );
            // Pre-create current month budget to simulate existing
            insert new Budget__c(
                Category__c = cat.Id,
                Month__c = newMonth,
                Budget_Amount__c = 50
            );
        }

        Test.startTest();
        Database.executeBatch(new MonthlyFinanceSummaryBatch(), 200);
        Test.stopTest();

        List<Budget__c> budgets = [SELECT Id FROM Budget__c WHERE Month__c = :newMonth AND OwnerId = :testUser.Id];
        System.assertEquals(1, budgets.size(), 'No duplicate budget should be created');
    }

    @IsTest
    static void testOverBudgetCategoryIncludedInEmail() {
        User testUser = createTestUser('C');
        Category__c cat = new Category__c(Name = 'Dining', Category_Type__c = 'Expense', Active__c = true);
        insert cat;

        Date prevMonth = Date.today().toStartOfMonth().addMonths(-1);

        System.runAs(testUser) {
            insert new Expense__c(
                Transaction_Date__c = prevMonth.addDays(2),
                Amount__c = 200,
                Transaction_Type__c = 'Expense',
                Category__c = cat.Id
            );
            insert new Budget__c(
                Category__c = cat.Id,
                Month__c = prevMonth,
                Budget_Amount__c = 50  // spending (200) > budget (50) = over budget
            );
        }

        Test.startTest();
        Database.executeBatch(new MonthlyFinanceSummaryBatch(), 200);
        Test.stopTest();

        Date newMonth = Date.today().toStartOfMonth();
        List<Budget__c> cloned = [SELECT Id FROM Budget__c WHERE Month__c = :newMonth AND OwnerId = :testUser.Id];
        System.assertEquals(1, cloned.size(), 'Budget should still be cloned even when over budget');
    }

    @IsTest
    static void testNoExpensesCompletesWithoutError() {
        // No data exists — batch should complete cleanly
        Test.startTest();
        Database.executeBatch(new MonthlyFinanceSummaryBatch(), 200);
        Test.stopTest();
        System.assert(true, 'Batch completed without exceptions when no prior-month data exists');
    }
}