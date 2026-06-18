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

    /** Picklist value on Status__c representing a completed task. */
    private static final String COMPLETED_STATUS = 'Completed';

    /**
     * @description  Handles logic for the before insert trigger event.
     *               Validates that Due_Date__c is not set to a past date and
     *               stamps Completed_Date__c when a task is created as Completed.
     * @param        newList  List of new Project_Task__c records being inserted.
     */
    public static void handleBeforeInsert(List<Project_Task__c> newList) {
        validateDueDate(newList);
        manageCompletedDate(newList, null);
    }

    /**
     * @description  Handles logic for the before update trigger event.
     *               Validates that Due_Date__c is not being changed to a past date
     *               and maintains Completed_Date__c based on Status__c transitions.
     * @param        newList  List of updated Project_Task__c records (new values).
     * @param        oldMap   Map of Project_Task__c records keyed by Id (old values).
     */
    public static void handleBeforeUpdate(List<Project_Task__c> newList, Map<Id, Project_Task__c> oldMap) {
        validateDueDate(newList);
        manageCompletedDate(newList, oldMap);
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

    /**
     * @description  Automatically maintains Completed_Date__c based on Status__c.
     *               On insert (oldMap null), stamps today's date when a record is
     *               created with a Completed status. On update, stamps today's date
     *               when the status transitions into Completed, and clears the date
     *               when the status transitions out of Completed.
     * @param        records  List of Project_Task__c records (new values) to process.
     * @param        oldMap   Map of prior record values keyed by Id; null on insert.
     */
    private static void manageCompletedDate(List<Project_Task__c> records, Map<Id, Project_Task__c> oldMap) {
        Date today = Date.today();
        for (Project_Task__c record : records) {
            Boolean newIsCompleted = COMPLETED_STATUS.equals(record.Status__c);

            if (oldMap == null) {
                // Before insert: stamp the date only when created as Completed.
                if (newIsCompleted) {
                    record.Completed_Date__c = today;
                }
                continue;
            }

            // Before update: act on Status__c transitions only.
            Project_Task__c oldRecord = oldMap.get(record.Id);
            Boolean oldIsCompleted = oldRecord != null && COMPLETED_STATUS.equals(oldRecord.Status__c);

            if (!oldIsCompleted && newIsCompleted) {
                record.Completed_Date__c = today;
            } else if (oldIsCompleted && !newIsCompleted) {
                record.Completed_Date__c = null;
            }
        }
    }
}
