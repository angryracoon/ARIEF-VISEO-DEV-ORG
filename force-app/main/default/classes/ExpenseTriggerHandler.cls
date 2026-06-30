/**
 * @class        ExpenseTriggerHandler
 * @description  Handler for ExpenseTrigger on Expense__c. Collects the set of
 *               FinancialAccount__c records affected by each DML event and
 *               delegates balance recalculation to ExpenseBalanceService.
 *               Keeps the trigger thin and the logic bulk-safe and testable.
 *
 *               Balance model: every Expense linked to a FinancialAccount
 *               decrements that account's Current_Balance__c by its Amount__c.
 *               Transaction_Type__c is irrelevant. Recalculation is a full
 *               aggregate recompute per affected account, so insert, update
 *               (amount change and/or reparenting), delete and undelete are all
 *               handled by the same idempotent path.
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
public with sharing class ExpenseTriggerHandler {

    /**
     * @description  Recursion guard. The balance update targets FinancialAccount__c,
     *               not Expense__c, so this trigger cannot re-enter itself today.
     *               The guard is a defensive backstop against future automation.
     */
    @TestVisible
    private static Boolean isProcessing = false;

    /**
     * @description  After insert: recalculate balances for every account newly
     *               referenced by the inserted expenses.
     * @param        newList  Inserted Expense__c records.
     */
    public static void handleAfterInsert(List<Expense__c> newList) {
        Set<Id> accountIds = collectAccountIds(newList);
        recalc(accountIds);
    }

    /**
     * @description  After update: recalculate balances for both the previously
     *               linked accounts and the newly linked accounts, covering amount
     *               changes and reparenting.
     * @param        newList  Updated Expense__c records (new values).
     * @param        oldMap   Prior Expense__c values keyed by Id.
     */
    public static void handleAfterUpdate(List<Expense__c> newList, Map<Id, Expense__c> oldMap) {
        Set<Id> accountIds = collectAccountIds(newList);
        accountIds.addAll(collectAccountIds(oldMap.values()));
        recalc(accountIds);
    }

    /**
     * @description  After delete: recalculate balances for every account that the
     *               deleted expenses were linked to (amounts are added back).
     * @param        oldList  Deleted Expense__c records.
     */
    public static void handleAfterDelete(List<Expense__c> oldList) {
        Set<Id> accountIds = collectAccountIds(oldList);
        recalc(accountIds);
    }

    /**
     * @description  After undelete: recalculate balances for every account that the
     *               restored expenses are linked to (amounts are deducted again).
     * @param        newList  Undeleted Expense__c records.
     */
    public static void handleAfterUndelete(List<Expense__c> newList) {
        Set<Id> accountIds = collectAccountIds(newList);
        recalc(accountIds);
    }

    /**
     * @description  Collects the non-null Financial_Account__c lookups from a list
     *               of Expense__c records.
     * @param        expenses  Records to inspect.
     * @return       Set of referenced FinancialAccount__c Ids.
     */
    private static Set<Id> collectAccountIds(List<Expense__c> expenses) {
        Set<Id> accountIds = new Set<Id>();
        for (Expense__c exp : expenses) {
            if (exp.Financial_Account__c != null) {
                accountIds.add(exp.Financial_Account__c);
            }
        }
        return accountIds;
    }

    /**
     * @description  Guards against re-entrancy and delegates to the balance service.
     * @param        accountIds  Accounts whose balance must be recalculated.
     */
    private static void recalc(Set<Id> accountIds) {
        if (isProcessing || accountIds.isEmpty()) {
            return;
        }
        isProcessing = true;
        try {
            ExpenseBalanceService.recalculateBalances(accountIds);
        } finally {
            isProcessing = false;
        }
    }
}
