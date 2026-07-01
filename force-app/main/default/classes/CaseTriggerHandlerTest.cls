/**
 * @description Test class for CaseTriggerHandler.
 *              Covers positive routing, negative (wrong status/priority), and bulk scenarios.
 */
@IsTest
private class CaseTriggerHandlerTest {

    private static Group createTier2Queue() {
        Group q = new Group(
            Name = 'Tier 2 Support',
            DeveloperName = 'Tier2_Support',
            Type = 'Queue'
        );
        insert q;
        QueueSObject qSobj = new QueueSObject(QueueId = q.Id, SObjectType = 'Case');
        insert qSobj;
        return q;
    }

    @IsTest
    static void testPositive_CriticalNew_AssignedToTier2Queue() {
        Group tier2Queue = createTier2Queue();

        Case c = new Case(Status = 'New', Support_Priority__c = 'Critical', Subject = 'Test Critical New');

        Test.startTest();
        insert c;
        Test.stopTest();

        Case result = [SELECT OwnerId FROM Case WHERE Id = :c.Id];
        Assert.areEqual(tier2Queue.Id, result.OwnerId, 'Critical+New Case should be routed to Tier2_Support queue');
    }

    @IsTest
    static void testNegative_WrongStatus_NotAssigned() {
        Group tier2Queue = createTier2Queue();

        Case c = new Case(Status = 'Working', Support_Priority__c = 'Critical', Subject = 'Test Critical Working', Impact__c = 'High');
        Id originalOwnerId = UserInfo.getUserId();
        c.OwnerId = originalOwnerId;

        Test.startTest();
        insert c;
        Test.stopTest();

        Case result = [SELECT OwnerId FROM Case WHERE Id = :c.Id];
        Assert.areNotEqual(tier2Queue.Id, result.OwnerId, 'Critical+Working Case should NOT be routed to Tier2_Support queue');
    }

    @IsTest
    static void testNegative_WrongPriority_NotAssigned() {
        Group tier2Queue = createTier2Queue();

        Case c = new Case(Status = 'New', Priority = 'High', Subject = 'Test High New');
        Id originalOwnerId = UserInfo.getUserId();
        c.OwnerId = originalOwnerId;

        Test.startTest();
        insert c;
        Test.stopTest();

        Case result = [SELECT OwnerId FROM Case WHERE Id = :c.Id];
        Assert.areNotEqual(tier2Queue.Id, result.OwnerId, 'High+New Case should NOT be routed to Tier2_Support queue');
    }

    @IsTest
    static void testBulk_200CriticalNew_AllAssignedWithSingleSoql() {
        Group tier2Queue = createTier2Queue();

        List<Case> cases = new List<Case>();
        for (Integer i = 0; i < 200; i++) {
            cases.add(new Case(
                Status = 'New',
                Support_Priority__c = 'Critical',
                Subject = 'Bulk Test Case ' + i
            ));
        }

        Test.startTest();
        insert cases;
        Integer queryCount = Limits.getQueries();
        Test.stopTest();

        List<Case> results = [SELECT OwnerId FROM Case WHERE Id IN :cases];
        Assert.areEqual(200, results.size(), 'All 200 cases should be inserted');
        for (Case result : results) {
            Assert.areEqual(tier2Queue.Id, result.OwnerId, 'Every bulk Critical+New Case should be routed to Tier2_Support queue');
        }
        Assert.areEqual(1, queryCount, 'Handler should issue exactly 1 SOQL query for 200 cases');
    }
}