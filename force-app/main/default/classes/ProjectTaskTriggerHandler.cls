/**
 * @class        ProjectTaskTriggerHandler
 * @description  Handler class for the ProjectTaskTrigger on Project_Task__c.
 *               Contains all business logic executed during before insert and
 *               before update trigger events. Follows the one-trigger-per-object
 *               + handler pattern to keep trigger files thin and logic testable.
 * @author       Arief Gunawan
 * @date         2026-06-17
 */
public with sharing class ProjectTaskTriggerHandler {

    /** Error message added to Due_Date__c when the date is set to a past value. */
    private static final String PAST_DATE_ERROR = 'Due Date cannot be in the past.';

    /**
     * @description  Handles logic for the before insert trigger event.
     *               Validates that Due_Date__c is not set to a past date.
     * @param        newList  List of new Project_Task__c records being inserted.
     */
    public static void handleBeforeInsert(List<Project_Task__c> newList) {
        validateDueDate(newList);
    }

    /**
     * @description  Handles logic for the before update trigger event.
     *               Validates that Due_Date__c is not being changed to a past date.
     * @param        newList  List of updated Project_Task__c records (new values).
     * @param        oldMap   Map of Project_Task__c records keyed by Id (old values).
     */
    public static void handleBeforeUpdate(List<Project_Task__c> newList, Map<Id, Project_Task__c> oldMap) {
        validateDueDate(newList);
    }

    /**
     * @description  Iterates over a list of Project_Task__c records and adds a
     *               field-level error on Due_Date__c if the value is earlier than
     *               today's date. Today itself is considered valid.
     * @param        records  List of Project_Task__c records to validate.
     */
    private static void validateDueDate(List<Project_Task__c> records) {
        Date today = Date.today();
        for (Project_Task__c record : records) {
            if (record.Due_Date__c != null && record.Due_Date__c < today) {
                record.Due_Date__c.addError(PAST_DATE_ERROR);
            }
        }
    }
}
