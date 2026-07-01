/**
 * @description Trigger on Case object for priority-based routing.
 *              Delegates all logic to CaseTriggerHandler (fallback when Case_Priority_Routing Flow is inactive).
 */
trigger CaseTrigger on Case (before insert, before update) {
    CaseTriggerHandler handler = new CaseTriggerHandler();
    if (Trigger.isBefore) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            handler.handleBeforeUpsert(Trigger.new);
        }
    }
}