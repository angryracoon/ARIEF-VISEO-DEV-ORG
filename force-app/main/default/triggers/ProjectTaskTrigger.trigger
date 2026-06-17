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
