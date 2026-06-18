# Project_Task__c Enhancement — Reminder Date, Completed Date, and Validation Rule

**Date:** 2026-06-17
**Status:** Completed
**Branch:** feature/2026-06-17-project-task-enhancement

---

## Overview

**Original request:** Enhance Project_Task__c with two new Date fields (Reminder_Date__c, Completed_Date__c), a validation rule preventing Reminder_Date__c from being after Due_Date__c, automatic Completed_Date__c maintenance based on Status__c transitions, and full test coverage.

**Summary:** This enhancement adds two Date fields to the existing Project_Task__c object. Reminder_Date__c is a user-managed field for scheduling reminders, constrained by a declarative validation rule that prevents it from being set after Due_Date__c. Completed_Date__c is a system-managed field that the trigger handler stamps automatically when a task's Status__c enters the Completed picklist value, and clears when it leaves. Three permission sets (Read Only, Read/Write, Delete) were created to control access to all six Project_Task__c fields and grant the appropriate object-level CRUD permissions.

---

## Components created

### Admin (declarative)

| Type | API name | Description |
|------|----------|-------------|
| Custom field | Project_Task__c.Reminder_Date__c | Date — optional user-managed reminder date |
| Custom field | Project_Task__c.Completed_Date__c | Date — optional, system-maintained by trigger on Status__c transition |
| Validation rule | Reminder_Not_After_Due_Date | Blocks save when Reminder_Date__c is after Due_Date__c |
| Permission set | ProjectTask_RO_PS | Object Read; field Read on all six Project_Task__c fields |
| Permission set | ProjectTask_RW_PS | Object Create/Read/Edit; field Read+Edit on all six fields |
| Permission set | ProjectTask_DELETE_PS | Object Read+Delete; field Read+Edit on all six fields |

### Development (code)

| Type | Name | Description |
|------|------|-------------|
| Apex class (updated) | ProjectTaskTriggerHandler | Added COMPLETED_STATUS constant and manageCompletedDate() method |
| Test class (updated) | ProjectTaskTriggerHandlerTest | Added 6 new test methods; 11 methods total, >= 95% coverage |

---

## New fields

### Reminder_Date__c

| Property | Value |
|----------|-------|
| Label | Reminder Date |
| API name | Reminder_Date__c |
| Type | Date |
| Required | No |
| Managed by | User (no automation) |
| History tracking | Off |

A user-populated field that holds the date on which a reminder should be triggered for this task. The field itself has no default value or formula. Its only constraint is the validation rule described below, which prevents it from being set to a date later than Due_Date__c.

### Completed_Date__c

| Property | Value |
|----------|-------|
| Label | Completed Date |
| API name | Completed_Date__c |
| Type | Date |
| Required | No |
| Managed by | ProjectTaskTriggerHandler (Apex, before insert / before update) |
| History tracking | Off |

A system-maintained field that records the calendar date on which the task's Status__c was last moved into the Completed value. It is cleared automatically if Status__c transitions back to any non-Completed value.

---

## Validation rule

### Reminder_Not_After_Due_Date

| Property | Value |
|----------|-------|
| Active | Yes |
| Error condition formula | `AND(NOT(ISBLANK(Reminder_Date__c)), NOT(ISBLANK(Due_Date__c)), Reminder_Date__c > Due_Date__c)` |
| Error message | Reminder Date cannot be after Due Date. |
| Error display field | Reminder_Date__c |

---

## Automation logic

### ProjectTaskTriggerHandler — Completed_Date__c management

| Context | Old Status__c | New Status__c | Action on Completed_Date__c |
|---------|---------------|---------------|------------------------------|
| Before insert | n/a | Completed | Set to `Date.today()` |
| Before insert | n/a | Not Completed | No change |
| Before update | Not Completed | Completed | Set to `Date.today()` |
| Before update | Completed | Not Completed | Set to `null` |
| Before update | Completed | Completed | No change |
| Before update | Not Completed | Not Completed | No change |

---

## Permission sets

| Permission Set | Object Perms | Field Perms |
|----------------|-------------|-------------|
| ProjectTask_RO_PS | Read | Read on all 6 fields |
| ProjectTask_RW_PS | Create, Read, Edit | Read+Edit on all 6 fields |
| ProjectTask_DELETE_PS | Create, Read, Edit, Delete | Read+Edit on all 6 fields |

---

## Test coverage

**Test class:** `ProjectTaskTriggerHandlerTest` — 11 methods, >= 95% coverage

| Method | What it covers |
|--------|----------------|
| `testInsertFutureDate_Success` | Future Due_Date__c inserts successfully |
| `testInsertTodayDate_Success` | Today Due_Date__c is valid |
| `testInsertPastDate_Fails` | Past Due_Date__c throws DmlException |
| `testUpdateToPastDate_Fails` | Updating Due_Date__c to past throws DmlException |
| `testUpdateToFutureDate_Success` | Updating Due_Date__c to future persists correctly |
| `testCompletedDatePopulatedOnInsert` | Insert with Status=Completed stamps Completed_Date__c |
| `testCompletedDatePopulatedOnStatusChange` | Status transition to Completed stamps Completed_Date__c |
| `testCompletedDateClearedOnStatusChange` | Status transition away from Completed clears Completed_Date__c |
| `testCompletedDateUnchangedOnNonCompletedStatusUpdate` | Non-Completed status update leaves Completed_Date__c null |
| `testValidReminderDateAllowed` | Reminder_Date__c before Due_Date__c inserts successfully |
| `testReminderDateAfterDueDateBlocked` | Reminder_Date__c after Due_Date__c throws DmlException |
