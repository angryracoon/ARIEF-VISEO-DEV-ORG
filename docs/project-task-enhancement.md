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

A system-maintained field that records the calendar date on which the task's Status__c was last moved into the Completed value. It is cleared automatically if Status__c transitions back to any non-Completed value. Although the field is editable at the metadata level, any value a user enters will be overwritten by the trigger handler whenever a relevant Status__c transition occurs. Users should treat this field as read-only in practice.

---

## Validation rule

### Reminder_Not_After_Due_Date

| Property | Value |
|----------|-------|
| Active | Yes |
| Error condition formula | `AND(NOT(ISBLANK(Reminder_Date__c)), NOT(ISBLANK(Due_Date__c)), Reminder_Date__c > Due_Date__c)` |
| Error message | Reminder Date cannot be after Due Date. |
| Error display field | Reminder_Date__c |

**When it fires:** The rule evaluates on every insert and update. It triggers only when both Reminder_Date__c and Due_Date__c are populated and Reminder_Date__c is strictly greater than Due_Date__c. A Reminder_Date__c equal to Due_Date__c is permitted. If either date field is blank, the rule does not fire.

**Error location:** The error message surfaces on the Reminder_Date__c field inline, not as a page-level error, giving users immediate context on which value to correct.

---

## Automation logic

### ProjectTaskTriggerHandler — Completed_Date__c management

The existing handler was extended with one new private constant and one new private method. The existing Due_Date__c past-date validation was preserved without modification.

#### Constant

```apex
private static final String COMPLETED_STATUS = 'Completed';
```

The picklist value is stored in a constant rather than a hardcoded string literal. This prevents silent failures if the string is mistyped and makes future picklist value changes a single-point-of-change in the handler.

#### manageCompletedDate(records, oldMap)

This private method is called by both public entry points (`handleBeforeInsert` and `handleBeforeUpdate`) and handles all four possible Status__c scenarios:

| Context | Old Status__c | New Status__c | Action on Completed_Date__c |
|---------|---------------|---------------|------------------------------|
| Before insert | n/a | Completed | Set to `Date.today()` |
| Before insert | n/a | Not Completed | No change (field remains null) |
| Before update | Not Completed | Completed | Set to `Date.today()` |
| Before update | Completed | Not Completed | Set to `null` |
| Before update | Completed | Completed | No change (no re-stamp) |
| Before update | Not Completed | Not Completed | No change |

**Insert path (oldMap is null):** The method stamps Completed_Date__c = Date.today() only if the incoming record's Status__c equals COMPLETED_STATUS. Non-completed inserts leave the field null.

**Update path (oldMap is provided):** The method reads the prior Status__c value from oldMap for each record and compares it to the new value. A transition into Completed stamps today's date; a transition out of Completed nullifies the field. Transitions that stay within the same category (Completed-to-Completed or non-Completed-to-non-Completed) produce no change, preventing unnecessary field writes.

#### Call chain

```
ProjectTaskTrigger (before insert, before update)
  └── ProjectTaskTriggerHandler.handleBeforeInsert(newList)
        ├── validateDueDate(newList)          -- existing logic, unchanged
        └── manageCompletedDate(newList, null)

  └── ProjectTaskTriggerHandler.handleBeforeUpdate(newList, oldMap)
        ├── validateDueDate(newList)          -- existing logic, unchanged
        └── manageCompletedDate(newList, oldMap)
```

The trigger file itself was not modified.

---

## Permission sets

All three permission sets are net-new (the permissionsets/ directory was empty before this enhancement). Assign them cumulatively: a user who needs delete access should receive both ProjectTask_RW_PS and ProjectTask_DELETE_PS, as the DELETE permission set does not independently grant Create/Edit without its own field and object permissions.

### ProjectTask_RO_PS — Project Task Read Only

| Property | Value |
|----------|-------|
| Label | Project Task Read Only |
| Object permission | Read |
| Field coverage | All six fields (read only) |

Grants read access to the object and read-only field visibility for: Task_Name__c, Status__c, Priority__c, Due_Date__c, Reminder_Date__c, Completed_Date__c. Users with only this permission set cannot create, edit, or delete records.

### ProjectTask_RW_PS — Project Task Read Write

| Property | Value |
|----------|-------|
| Label | Project Task Read Write |
| Object permission | Create, Read, Edit |
| Field coverage | All six fields (read + edit) |

Grants full read/write access to the object and all six fields. Delete is not included. Users with this permission set can create tasks and modify any field value, including Reminder_Date__c and Completed_Date__c, subject to the validation rule and trigger logic.

### ProjectTask_DELETE_PS — Project Task Delete

| Property | Value |
|----------|-------|
| Label | Project Task Delete |
| Object permission | Create, Read, Edit, Delete |
| Field coverage | All six fields (read + edit) |

Grants full CRUD including delete. Intended for administrators or senior users who need to permanently remove task records. Field permissions mirror ProjectTask_RW_PS.

---

## Test coverage

**Test class:** `ProjectTaskTriggerHandlerTest`
**Total methods:** 11 (5 pre-existing + 6 new)
**Reported coverage:** >= 95% on ProjectTaskTriggerHandler

### Pre-existing test methods (5)

| Method | What it covers |
|--------|----------------|
| `testInsertFutureDate_Success` | Insert with a future Due_Date__c succeeds; record Id is not null |
| `testInsertTodayDate_Success` | Insert with Due_Date__c = today succeeds; today is not a past date |
| `testInsertPastDate_Fails` | Insert with Due_Date__c yesterday throws DmlException containing "Due Date cannot be in the past." |
| `testUpdateToPastDate_Fails` | Updating Due_Date__c to yesterday on an existing record throws DmlException with the same message |
| `testUpdateToFutureDate_Success` | Updating Due_Date__c to a future date persists the new value correctly |

### New test methods (6)

| Method | What it covers |
|--------|----------------|
| `testCompletedDatePopulatedOnInsert` | Insert with Status__c = Completed stamps Completed_Date__c = today on the saved record |
| `testCompletedDatePopulatedOnStatusChange` | Update transitioning Status__c from In Progress to Completed stamps Completed_Date__c = today |
| `testCompletedDateClearedOnStatusChange` | Update transitioning Status__c from Completed to In Progress nullifies Completed_Date__c |
| `testCompletedDateUnchangedOnNonCompletedStatusUpdate` | Update from Not Started to In Progress leaves Completed_Date__c null throughout |
| `testValidReminderDateAllowed` | Insert with Reminder_Date__c before Due_Date__c succeeds; no validation rule error |
| `testReminderDateAfterDueDateBlocked` | Insert with Reminder_Date__c after Due_Date__c throws DmlException whose message contains "Reminder Date" |

---

## Deployment notes

Deploy components in the following order to avoid dependency errors.

**Step 1 — New fields first**

Deploy Reminder_Date__c and Completed_Date__c field metadata before deploying the handler or validation rule. The handler references Completed_Date__c at compile time; the validation rule references Reminder_Date__c. Neither will compile or activate successfully if the fields do not already exist in the org.

```
force-app/main/default/objects/Project_Task__c/fields/Reminder_Date__c.field-meta.xml
force-app/main/default/objects/Project_Task__c/fields/Completed_Date__c.field-meta.xml
```

**Step 2 — Updated handler and test class**

Deploy the updated Apex class and its test class together in the same deployment unit.

```
force-app/main/default/classes/ProjectTaskTriggerHandler.cls
force-app/main/default/classes/ProjectTaskTriggerHandler.cls-meta.xml
force-app/main/default/classes/ProjectTaskTriggerHandlerTest.cls
force-app/main/default/classes/ProjectTaskTriggerHandlerTest.cls-meta.xml
```

**Step 3 — Validation rule**

Deploy the validation rule after the fields are confirmed present. The validation rule is declarative and does not need to be bundled with the Apex classes.

```
force-app/main/default/objects/Project_Task__c/validationRules/Reminder_Not_After_Due_Date.validationRule-meta.xml
```

**Step 4 — Permission sets**

Deploy all three permission sets last, after the fields are in place, so field permission entries resolve correctly.

```
force-app/main/default/permissionsets/ProjectTask_RO_PS.permissionset-meta.xml
force-app/main/default/permissionsets/ProjectTask_RW_PS.permissionset-meta.xml
force-app/main/default/permissionsets/ProjectTask_DELETE_PS.permissionset-meta.xml
```

The Salesforce DevOps agent (`salesforce-devops`) handles full deployment from main after the PR is merged and should deploy all components as one package, respecting the dependency order above.

---

## File locations

| Component | Path |
|-----------|------|
| Reminder_Date__c field | `force-app/main/default/objects/Project_Task__c/fields/Reminder_Date__c.field-meta.xml` |
| Completed_Date__c field | `force-app/main/default/objects/Project_Task__c/fields/Completed_Date__c.field-meta.xml` |
| Validation rule | `force-app/main/default/objects/Project_Task__c/validationRules/Reminder_Not_After_Due_Date.validationRule-meta.xml` |
| Trigger handler class | `force-app/main/default/classes/ProjectTaskTriggerHandler.cls` |
| Test class | `force-app/main/default/classes/ProjectTaskTriggerHandlerTest.cls` |
| Permission set — RO | `force-app/main/default/permissionsets/ProjectTask_RO_PS.permissionset-meta.xml` |
| Permission set — RW | `force-app/main/default/permissionsets/ProjectTask_RW_PS.permissionset-meta.xml` |
| Permission set — DELETE | `force-app/main/default/permissionsets/ProjectTask_DELETE_PS.permissionset-meta.xml` |

---

## Security model

- `ProjectTaskTriggerHandler` is declared `public with sharing`, enforcing the running user's sharing rules.
- No SOQL queries are executed inside the handler (logic operates on trigger context records only), so WITH USER_MODE is not applicable.
- Field-level security is enforced through the three permission sets above; no field access is granted through profiles directly.

---

## Known limitations and future enhancements

- **Completed_Date__c is not re-stamped on repeated Completed-to-Completed updates.** If a task is completed, re-opened, and completed again, the date reflects the most recent transition into Completed. This is the intended behavior but should be communicated to users who expect the original completion date to be preserved.
- **No flow or process automation.** Reminder_Date__c is stored but no notification, task, or email alert is created when the reminder date arrives. A scheduled Flow or a Platform Event listener could be added in a future enhancement to send reminders.
- **DELETE permission set includes Create/Edit.** The current permission set grants full CRUD to match typical admin use cases, but a stricter implementation could restrict the DELETE set to Read + Delete only if the org's security model requires it.
- **No Chatter feed tracking.** Both new fields have trackFeedHistory and trackHistory set to false. Enable field history tracking on Completed_Date__c if an audit trail of completion dates is required.

---

## Change history

| Date | Change |
|------|--------|
| 2026-06-17 | Fields Reminder_Date__c and Completed_Date__c added to Project_Task__c |
| 2026-06-17 | Validation rule Reminder_Not_After_Due_Date added |
| 2026-06-17 | ProjectTaskTriggerHandler updated with COMPLETED_STATUS constant and manageCompletedDate() |
| 2026-06-17 | ProjectTaskTriggerHandlerTest updated — 6 new methods added, 11 total |
| 2026-06-17 | Three permission sets (RO, RW, DELETE) created net-new |
