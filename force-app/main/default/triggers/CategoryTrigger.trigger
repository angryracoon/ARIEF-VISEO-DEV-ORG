trigger CategoryTrigger on Category__c (before delete) {
    CategoryTriggerHandler handler = new CategoryTriggerHandler();
    if (Trigger.isBefore && Trigger.isDelete) {
        handler.handleBeforeDelete(Trigger.old);
    }
}