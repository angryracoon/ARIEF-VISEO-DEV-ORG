public with sharing class CategoryTriggerHandler {

    private static final String ERROR_MSG =
        'This Category cannot be deleted because it has associated Expense or Budget records. ' +
        'Please reassign or delete those records first.';

    public void handleBeforeDelete(List<Category__c> categories) {
        Set<Id> categoryIds = new Set<Id>();
        for (Category__c cat : categories) {
            categoryIds.add(cat.Id);
        }

        Set<Id> blockedCategoryIds = getCategoriesWithChildren(categoryIds);

        if (blockedCategoryIds.isEmpty()) {
            return;
        }

        for (Category__c cat : categories) {
            if (blockedCategoryIds.contains(cat.Id)) {
                cat.addError(ERROR_MSG);
            }
        }
    }

    @TestVisible
    private Set<Id> getCategoriesWithChildren(Set<Id> categoryIds) {
        Set<Id> blocked = new Set<Id>();

        for (AggregateResult ar : [
            SELECT Category__c catId
            FROM Expense__c
            WHERE Category__c IN :categoryIds
            WITH USER_MODE
            GROUP BY Category__c
        ]) {
            blocked.add((Id) ar.get('catId'));
        }

        for (AggregateResult ar : [
            SELECT Category__c catId
            FROM Budget__c
            WHERE Category__c IN :categoryIds
            WITH USER_MODE
            GROUP BY Category__c
        ]) {
            blocked.add((Id) ar.get('catId'));
        }

        return blocked;
    }
}