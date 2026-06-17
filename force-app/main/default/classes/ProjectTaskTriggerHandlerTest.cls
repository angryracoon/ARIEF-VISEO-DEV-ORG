/**
 * @class        ProjectTaskTriggerHandlerTest
 * @description  Test class for ProjectTaskTriggerHandler.
 *               Covers the before insert and before update validation that prevents
 *               Due_Date__c from being set to a past date on Project_Task__c records.
 *               All 5 test methods combined achieve >= 90% code coverage.
 * @author       Arief Gunawan
 * @date         2026-06-17
 * @see          ProjectTaskTriggerHandler
 * @see          ProjectTaskTrigger
 */
@isTest
private class ProjectTaskTriggerHandlerTest {

    /**
     * @description  Verifies that inserting a Project_Task__c record with a future
     *               Due_Date__c succeeds without any errors.
     */
    @isTest
    static void testInsertFutureDate_Success() {
        Project_Task__c task = new Project_Task__c(
            Task_Name__c = 'Future Task',
            Due_Date__c = Date.today().addDays(1),
            Status__c = 'Not Started',
            Priority__c = 'Medium'
        );
        Test.startTest();
        insert task;
        Test.stopTest();
        System.assertNotEquals(null, task.Id, 'Record should have been inserted successfully.');
    }

    /**
     * @description  Verifies that inserting a Project_Task__c record with Due_Date__c
     *               set to today succeeds — today is not considered a past date.
     */
    @isTest
    static void testInsertTodayDate_Success() {
        Project_Task__c task = new Project_Task__c(
            Task_Name__c = 'Today Task',
            Due_Date__c = Date.today(),
            Status__c = 'Not Started',
            Priority__c = 'Low'
        );
        Test.startTest();
        insert task;
        Test.stopTest();
        System.assertNotEquals(null, task.Id, 'Record with today date should insert successfully.');
    }

    /**
     * @description  Verifies that inserting a Project_Task__c record with Due_Date__c
     *               set to yesterday throws a DmlException with the expected field-level
     *               error message "Due Date cannot be in the past."
     */
    @isTest
    static void testInsertPastDate_Fails() {
        Project_Task__c task = new Project_Task__c(
            Task_Name__c = 'Past Task',
            Due_Date__c = Date.today().addDays(-1),
            Status__c = 'Not Started',
            Priority__c = 'High'
        );
        Test.startTest();
        try {
            insert task;
            System.assert(false, 'Insert should have thrown a DmlException for past due date.');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('Due Date cannot be in the past.'),
                'Expected past due date error. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description  Verifies that updating an existing Project_Task__c record by
     *               changing Due_Date__c to a past date throws a DmlException with
     *               the expected field-level error message.
     */
    @isTest
    static void testUpdateToPastDate_Fails() {
        Project_Task__c task = new Project_Task__c(
            Task_Name__c = 'Update Task',
            Due_Date__c = Date.today().addDays(5),
            Status__c = 'In Progress',
            Priority__c = 'Medium'
        );
        insert task;

        task.Due_Date__c = Date.today().addDays(-1);
        Test.startTest();
        try {
            update task;
            System.assert(false, 'Update should have thrown a DmlException for past due date.');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('Due Date cannot be in the past.'),
                'Expected past due date error. Got: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    /**
     * @description  Verifies that updating an existing Project_Task__c record by
     *               changing Due_Date__c to a future date succeeds and the new value
     *               is persisted correctly.
     */
    @isTest
    static void testUpdateToFutureDate_Success() {
        Project_Task__c task = new Project_Task__c(
            Task_Name__c = 'Reschedule Task',
            Due_Date__c = Date.today().addDays(3),
            Status__c = 'Not Started',
            Priority__c = 'Low'
        );
        insert task;

        task.Due_Date__c = Date.today().addDays(10);
        Test.startTest();
        update task;
        Test.stopTest();

        Project_Task__c updated = [SELECT Due_Date__c FROM Project_Task__c WHERE Id = :task.Id];
        System.assertEquals(
            Date.today().addDays(10),
            updated.Due_Date__c,
            'Due date should have been updated to future date.'
        );
    }
}
