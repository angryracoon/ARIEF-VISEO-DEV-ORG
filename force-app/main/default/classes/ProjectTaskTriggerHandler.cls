public with sharing class ProjectTaskTriggerHandler {

    private static final String PAST_DATE_ERROR = 'Due Date cannot be in the past.';

    public static void handleBeforeInsert(List<Project_Task__c> newList) {
        validateDueDate(newList);
    }

    public static void handleBeforeUpdate(List<Project_Task__c> newList, Map<Id, Project_Task__c> oldMap) {
        validateDueDate(newList);
    }

    private static void validateDueDate(List<Project_Task__c> records) {
        Date today = Date.today();
        for (Project_Task__c record : records) {
            if (record.Due_Date__c != null && record.Due_Date__c < today) {
                record.Due_Date__c.addError(PAST_DATE_ERROR);
            }
        }
    }
}
