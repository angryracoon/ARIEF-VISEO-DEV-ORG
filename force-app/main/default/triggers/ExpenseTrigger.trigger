/**
 * @trigger      ExpenseTrigger
 * @object       Expense__c
 * @events       after insert, after update, after delete, after undelete
 * @description  Entry point for all Expense__c trigger logic. Delegates to
 *               ExpenseTriggerHandler — no business logic lives in this file
 *               (one-trigger-per-object pattern). Runs after the existing
 *               Expense_Update_Budget_Spending record-triggered flow; the two
 *               operate on different target objects and do not conflict.
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
trigger ExpenseTrigger on Expense__c (after insert, after update, after delete, after undelete) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert) {
            ExpenseTriggerHandler.handleAfterInsert(Trigger.new);
        } else if (Trigger.isUpdate) {
            ExpenseTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
        } else if (Trigger.isDelete) {
            ExpenseTriggerHandler.handleAfterDelete(Trigger.old);
        } else if (Trigger.isUndelete) {
            ExpenseTriggerHandler.handleAfterUndelete(Trigger.new);
        }
    }
}
