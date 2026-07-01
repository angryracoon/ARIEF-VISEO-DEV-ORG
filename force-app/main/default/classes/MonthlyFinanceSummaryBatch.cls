public without sharing class MonthlyFinanceSummaryBatch implements Database.Batchable<SObject> {

    private Date previousMonthStart;
    private Date previousMonthEnd;
    private Date newMonthStart;

    public MonthlyFinanceSummaryBatch() {
        Date today = Date.today();
        newMonthStart = Date.newInstance(today.year(), today.month(), 1);
        previousMonthStart = newMonthStart.addMonths(-1);
        previousMonthEnd = newMonthStart.addDays(-1);
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Email, Name
            FROM User
            WHERE IsActive = true
              AND Id IN (
                  SELECT OwnerId
                  FROM Expense__c
                  WHERE Transaction_Date__c >= :previousMonthStart
                    AND Transaction_Date__c <= :previousMonthEnd
              )
        ]);
    }

    public void execute(Database.BatchableContext bc, List<User> scope) {
        Set<Id> userIds = new Map<Id, User>(scope).keySet();

        // Bulk-query all expenses for users in this batch chunk
        Map<Id, List<Expense__c>> expensesByUser = new Map<Id, List<Expense__c>>();
        for (Id uid : userIds) {
            expensesByUser.put(uid, new List<Expense__c>());
        }
        for (Expense__c e : [
            SELECT Id, OwnerId, Amount__c, Transaction_Type__c
            FROM Expense__c
            WHERE OwnerId IN :userIds
              AND Transaction_Date__c >= :previousMonthStart
              AND Transaction_Date__c <= :previousMonthEnd
        ]) {
            expensesByUser.get(e.OwnerId).add(e);
        }

        // Bulk-query previous month budgets
        Map<Id, List<Budget__c>> prevBudgetsByUser = new Map<Id, List<Budget__c>>();
        for (Id uid : userIds) {
            prevBudgetsByUser.put(uid, new List<Budget__c>());
        }
        for (Budget__c b : [
            SELECT Id, OwnerId, Category__c, Category__r.Name, Budget_Amount__c, Total_Spending__c
            FROM Budget__c
            WHERE OwnerId IN :userIds
              AND Month__c >= :previousMonthStart
              AND Month__c <= :previousMonthEnd
        ]) {
            prevBudgetsByUser.get(b.OwnerId).add(b);
        }

        // Bulk-query existing new-month budgets to prevent duplicates
        Map<Id, Set<Id>> existingNewMonthCatsByUser = new Map<Id, Set<Id>>();
        for (Id uid : userIds) {
            existingNewMonthCatsByUser.put(uid, new Set<Id>());
        }
        for (Budget__c b : [
            SELECT OwnerId, Category__c
            FROM Budget__c
            WHERE OwnerId IN :userIds
              AND Month__c = :newMonthStart
        ]) {
            existingNewMonthCatsByUser.get(b.OwnerId).add(b.Category__c);
        }

        // Process each user
        List<Budget__c> budgetsToInsert = new List<Budget__c>();
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (User u : scope) {
            List<Expense__c> expenses = expensesByUser.get(u.Id);
            List<Budget__c> prevBudgets = prevBudgetsByUser.get(u.Id);
            Set<Id> existingCatIds = existingNewMonthCatsByUser.get(u.Id);

            Decimal totalIncome = 0;
            Decimal totalExpenses = 0;
            for (Expense__c e : expenses) {
                Decimal amt = (e.Amount__c != null ? e.Amount__c : 0);
                if (e.Transaction_Type__c == 'Income') {
                    totalIncome += amt;
                } else if (e.Transaction_Type__c == 'Expense') {
                    totalExpenses += amt;
                }
            }
            Decimal netSavings = totalIncome - totalExpenses;

            List<String> overBudgetCategories = new List<String>();
            for (Budget__c b : prevBudgets) {
                Decimal spending = (b.Total_Spending__c != null ? b.Total_Spending__c : 0);
                Decimal budgetAmt = (b.Budget_Amount__c != null ? b.Budget_Amount__c : 0);
                if (spending > budgetAmt) {
                    overBudgetCategories.add(b.Category__r.Name);
                }
                if (!existingCatIds.contains(b.Category__c)) {
                    budgetsToInsert.add(new Budget__c(
                        Category__c = b.Category__c,
                        Budget_Amount__c = b.Budget_Amount__c,
                        Month__c = newMonthStart,
                        OwnerId = u.Id
                    ));
                    existingCatIds.add(b.Category__c);
                }
            }

            if (String.isNotBlank(u.Email)) {
                emails.add(buildEmail(u, totalIncome, totalExpenses, netSavings, overBudgetCategories));
            }
        }

        if (!budgetsToInsert.isEmpty()) {
            insert budgetsToInsert;
        }
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    private Messaging.SingleEmailMessage buildEmail(User u, Decimal totalIncome, Decimal totalExpenses,
                                                     Decimal netSavings, List<String> overBudgetCategories) {
        String subject = String.format(
            System.Label.PFT_Monthly_Email_Subject,
            new List<Object>{ previousMonthStart.month() + '/' + previousMonthStart.year() }
        );

        String overBudgetHtml = overBudgetCategories.isEmpty()
            ? '<p>All categories within budget. Great work!</p>'
            : '<ul>' + buildListItems(overBudgetCategories) + '</ul>';

        String body = '<html><body>'
            + '<h2>Hi ' + u.Name + ',</h2>'
            + '<p>Finance summary for <strong>'
            + previousMonthStart.month() + '/' + previousMonthStart.year() + '</strong>:</p>'
            + '<table border="1" cellpadding="6" cellspacing="0">'
            + '<tr><td><strong>Total Income</strong></td><td>' + totalIncome.format() + '</td></tr>'
            + '<tr><td><strong>Total Expenses</strong></td><td>' + totalExpenses.format() + '</td></tr>'
            + '<tr><td><strong>Net Savings</strong></td><td>' + netSavings.format() + '</td></tr>'
            + '</table>'
            + '<h3>Categories Over Budget</h3>'
            + overBudgetHtml
            + '<p>Budgets for this month have been auto-created from last month.</p>'
            + '</body></html>';

        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ u.Email });
        email.setSubject(subject);
        email.setHtmlBody(body);
        email.setSaveAsActivity(false);
        return email;
    }

    private String buildListItems(List<String> items) {
        String html = '';
        for (String item : items) {
            html += '<li>' + item + '</li>';
        }
        return html;
    }

    public void finish(Database.BatchableContext bc) {
        // No post-processing needed
    }
}