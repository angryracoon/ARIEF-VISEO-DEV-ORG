/**
 * @description Handler for CaseTrigger. Routes Critical+New Cases to the Tier2_Support queue.
 *              Acts as the Apex fallback when the Case_Priority_Routing Flow is inactive.
 *              Bulk-safe: single SOQL on Group object, no SOQL/DML inside loops.
 */
public with sharing class CaseTriggerHandler {

    private static final String TIER2_QUEUE_DEVELOPER_NAME = 'Tier2_Support';
    private static final String STATUS_NEW = 'New';
    private static final String SUPPORT_PRIORITY_CRITICAL = 'Critical';

    /**
     * @description Handles before insert and before update events.
     *              Assigns Tier2_Support queue as owner for Critical+New Cases.
     * @param cases List of Case records from Trigger.new
     */
    public void handleBeforeUpsert(List<Case> cases) {
        List<Case> eligibleCases = filterEligibleCases(cases);
        if (eligibleCases.isEmpty()) {
            return;
        }

        Id tier2QueueId = getTier2SupportQueueId();
        if (tier2QueueId == null) {
            return;
        }

        for (Case c : eligibleCases) {
            c.OwnerId = tier2QueueId;
        }
    }

    /**
     * @description Filters cases that qualify for Tier2 routing (Status=New, Priority=Critical).
     * @param cases Input list of cases
     * @return Filtered list of eligible cases
     */
    private List<Case> filterEligibleCases(List<Case> cases) {
        List<Case> eligible = new List<Case>();
        for (Case c : cases) {
            if (STATUS_NEW.equals(c.Status) && SUPPORT_PRIORITY_CRITICAL.equals(c.Support_Priority__c)) {
                eligible.add(c);
            }
        }
        return eligible;
    }

    /**
     * @description Queries for the Tier2_Support queue Id. Single SOQL — bulk-safe.
     * @return The Id of the Tier2_Support queue, or null if not found
     */
    private Id getTier2SupportQueueId() {
        List<Group> queues = [
            SELECT Id
            FROM Group
            WHERE DeveloperName = :TIER2_QUEUE_DEVELOPER_NAME
                AND Type = 'Queue'
            WITH USER_MODE
            LIMIT 1
        ];
        return queues.isEmpty() ? null : queues[0].Id;
    }
}