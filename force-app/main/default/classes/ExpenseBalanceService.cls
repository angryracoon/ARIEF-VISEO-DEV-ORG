/**
 * @class        ExpenseBalanceService
 * @description  Maintains FinancialAccount__c.Current_Balance__c from linked
 *               Expense__c records. The balance equals the negative sum of all
 *               linked expense amounts (every expense decrements the balance by
 *               its Amount__c). Recalculation is a full aggregate recompute per
 *               account, making it idempotent and safe to call from any trigger
 *               event (insert, update, delete, undelete).
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
public with sharing class ExpenseBalanceService {

    /**
     * @description  Recomputes Current_Balance__c for each supplied account as the
     *               negative SUM of its linked Expense__c amounts. Accounts with no
     *               remaining linked expenses are reset to zero.
     *
     *               The aggregate read runs in USER_MODE (the running user can read
     *               Expense amounts). The balance write runs in system mode by design:
     *               Current_Balance__c is field-level read-only for end users, so it
     *               can only be maintained by this trusted, system-managed path.
     * @param        accountIds  FinancialAccount__c Ids to recalculate.
     */
    public static void recalculateBalances(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        Map<Id, Decimal> totalsByAccount = new Map<Id, Decimal>();
        for (AggregateResult ar : [
            SELECT Financial_Account__c accountId, SUM(Amount__c) total
            FROM Expense__c
            WHERE Financial_Account__c IN :accountIds
            WITH USER_MODE
            GROUP BY Financial_Account__c
        ]) {
            Decimal total = (Decimal) ar.get('total');
            totalsByAccount.put((Id) ar.get('accountId'), total == null ? 0 : total);
        }

        List<FinancialAccount__c> accountsToUpdate = new List<FinancialAccount__c>();
        for (Id accountId : accountIds) {
            Decimal spent = totalsByAccount.containsKey(accountId)
                ? totalsByAccount.get(accountId)
                : 0;
            accountsToUpdate.add(new FinancialAccount__c(
                Id = accountId,
                Current_Balance__c = spent * -1
            ));
        }

        if (!accountsToUpdate.isEmpty()) {
            // System-mode update: Current_Balance__c is read-only at FLS for users.
            update accountsToUpdate;
        }
    }
}
