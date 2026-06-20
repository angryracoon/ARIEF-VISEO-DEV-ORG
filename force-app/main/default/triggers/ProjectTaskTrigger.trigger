/**
 * @trigger      ProjectTaskTrigger
 * @object       Project_Task__c
 * @events       before insert, before update
 * @description  Entry point for all Project_Task__c trigger logic.
 *               Delegates execution to ProjectTaskTriggerHandler — no
 *               business logic lives in this file (one-trigger-per-object pattern).
 * @author       Arief Gunawan
 * @date         2026-06-17
 */
trigger ProjectTaskTrigger on Project_Task__c (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ProjectTaskTriggerHandler.handleBeforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            ProjectTaskTriggerHandler.handleBeforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}