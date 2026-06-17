@isTest
private class ProjectTaskTriggerHandlerTest {

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
