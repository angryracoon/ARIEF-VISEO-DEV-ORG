# Project Delivery Management — System Documentation

**Sprint:** 1 (feature/2026-06-19-project-delivery-management-sprint1) + Sprint 2 corrections (feature/2026-06-20-project-delivery-sprint2-corrections)
**API Version:** 65.0
**Last Updated:** 2026-06-21

---

## Overview

The Project Delivery Management system tracks VISEO consulting project execution within Salesforce. It extends the standard Opportunity object with a `VISEO_Project_Opportunity` record type and introduces three custom objects — Project Sprint, Project Activity, and Project Sign Off — to manage the delivery lifecycle from kick-off through client sign-off.

Key capabilities:
- Opportunity-driven project tracking with manday rollups and VISEO-specific stage progression
- Sprint-based activity management with status enforcement and open-activity validation
- Per-stage client sign-off workflow with document upload and approval stamping
- Task management with due-date validation, automated completion-date stamping, and scheduled push-notification reminders

---

## Data Model

### Objects

#### Opportunity (standard, extended)

Used as the top-level project record via the `VISEO_Project_Opportunity` record type.

| Field API Name | Label | Type | Notes |
|---|---|---|---|
| StageName (standard) | Stage Name | Picklist | Controlled by `VISEO_Sales_Process` Business Process; 9 VISEO stages added (Discovery through AMS) |
| Total_Planned_Mandays__c | Total Planned Mandays | (rollup — full def in org) | Rolls up Planned_Mandays__c from related Project Sprints |
| Total_Actual_Mandays__c | Total Actual Mandays | (rollup — full def in org) | Rolls up Actual_Mandays__c from related Project Sprints |
| Current_Stage_Sign_Off_Complete__c | Current Stage Sign Off Complete | Checkbox | Set to true by the Upload Sign-Off Document flow upon approval |

The full set of Opportunity custom fields (Project_Description__c, Project_Scope__c, Start_Date__c, Planned_Go_Live_Date__c, Actual_Go_Live_Date__c, Planned_Mandays__c, Actual_Mandays__c, Project_Health__c, Delivery_Methodology__c, Total_Sprints__c) are present in org. Only Total_Planned_Mandays__c, Total_Actual_Mandays__c, and Current_Stage_Sign_Off_Complete__c have source metadata files in this repository; the remainder were created directly in org prior to Sprint 1 and are tracked via org configuration only.

**Record type:** `VISEO_Project_Opportunity` — label "VISEO Project Opportunity", linked to `VISEO_Sales_Process` business process.

---

#### Project_Sprint__c

Represents a time-boxed unit of delivery work. Child of Opportunity.

**Object settings:** Sharing model = ReadWrite, Reports enabled, Search enabled, Activities enabled, Streaming API enabled.

| Field API Name | Label | Type | Notes |
|---|---|---|---|
| Name (standard) | Project Sprint Name | Auto-Number or Text | Standard name field |
| Sprint_Status__c | Sprint Status | Picklist | Values: Planning (default), In Progress, Complete, Cancelled, Closed |
| Total_Open_Activities__c | Total Open Activities | Summary (COUNT) | Counts Project_Activity__c records on this sprint where Activity_Status__c is not Completed, not Cancelled, and not Closed |
| Total_Activities__c | Total Activities | (rollup — full def in org) | Total count of all related activities |
| Total_Completed_Activities__c | Total Completed Activities | (rollup — full def in org) | Count of activities with Completed status |

Additional fields visible on the Lightning Record Page (Total_Activities__c, Total_Completed_Activities__c) are present in org but do not have source metadata files in this repository.

**Validation rule:** `Prevent_Close_With_Open_Activities` — see Automation section.

---

#### Project_Activity__c

Represents a discrete unit of work within a sprint. Child of Project_Sprint__c.

**Object settings:** Activities enabled, Chatter feed tracking enabled.

| Field API Name | Label | Type | Notes |
|---|---|---|---|
| Name (standard) | Project Activity Name | Text | Standard name field |
| Project_Sprint__c | Project Sprint | Lookup (Project_Sprint__c) | Master lookup to parent sprint |
| Activity_Status__c | Activity Status | Picklist | Values: Not Started (default), In Progress, In Review, Completed, Blocked, Cancelled, Closed |

The Chatter feed is displayed on the right panel of the Project Activity Record Page.

---

#### Project_Sign_Off__c

Tracks client approval for each project delivery stage. Child of Opportunity.

**Note:** Project_Sign_Off__c is present in org and referenced in flows and flexipages. Its full object definition and fields (Stage__c, Sign_Off_Status__c, Approval_Date__c, Approved_By__c, Opportunity__c) exist in org but do not have source metadata files in this repository — they were created prior to Sprint 1. The upload flow queries and updates these fields directly.

| Field API Name | Label | Type | Notes |
|---|---|---|---|
| Name (standard) | Project Sign Off Name | Text | Standard name field |
| Stage__c | Stage | Picklist or Text | Identifies which project stage this sign-off covers |
| Sign_Off_Status__c | Sign Off Status | Picklist | Updated to "Approved" by the Upload Document flow |
| Approval_Date__c | Approval Date | Date | Stamped to today's date by the Upload Document flow |
| Approved_By__c | Approved By | Lookup or Text | Set to current user by the Upload Document flow |
| Opportunity__c | Opportunity | Lookup (Opportunity) | Parent opportunity record |

---

#### Project_Task__c

Represents a discrete task within the project, not directly tied to a sprint. Standalone child record.

**Object settings:** Sharing model = ReadWrite, Reports enabled, Search enabled, Activities enabled, Streaming API enabled.

| Field API Name | Label | Type | Notes |
|---|---|---|---|
| Name (standard) | Project Task Name | Text | Standard name field |
| Task_Name__c | Task Name | Text(255) | Descriptive name for the task |
| Status__c | Status | Picklist (restricted) | Values: Not Started (default), In Progress, Completed |
| Priority__c | Priority | Picklist (restricted) | Values: Low, Medium, High |
| Due_Date__c | Due Date | Date | Cannot be set to a past date (enforced by trigger) |
| Reminder_Date__c | Reminder Date | Date | User-managed; cannot be after Due_Date__c (validation rule); triggers a scheduled push notification |
| Completed_Date__c | Completed Date | Date | System-managed by trigger: stamped when Status__c = Completed, cleared when Status__c leaves Completed |

**Validation rule:** `Reminder_Not_After_Due_Date`
- Formula: `AND(NOT(ISBLANK(Reminder_Date__c)), NOT(ISBLANK(Due_Date__c)), Reminder_Date__c > Due_Date__c)`
- Error message: "Reminder Date cannot be after Due Date."
- Error field: Reminder_Date__c

---

### Object Relationships

```
Opportunity (VISEO_Project_Opportunity record type)
  |
  +-- Project_Sprint__c (lookup: Opportunity__c)
  |     |
  |     +-- Project_Activity__c (lookup: Project_Sprint__c)
  |
  +-- Project_Sign_Off__c (lookup: Opportunity__c)

Project_Task__c (standalone — no parent lookup in current implementation)
```

Roll-up summary fields flow upward:
- Activity_Status__c on Project_Activity__c feeds Total_Open_Activities__c on Project_Sprint__c
- Sprint manday fields roll up to Total_Planned_Mandays__c and Total_Actual_Mandays__c on Opportunity
- Total_Sprints__c on Opportunity counts all related Project Sprint records

---

## Automation

### Flows

#### Project_Task_After_Save

| Property | Value |
|---|---|
| API Name | Project_Task_After_Save |
| Label | Project Task After Save |
| Type | Record-Triggered Flow (After Save) |
| Object | Project_Task__c |
| Trigger events | Create and Update |
| Status | Active |

**Entry condition:** Fires only when `Reminder_Date__c` is not null.

**Scheduled path — "3 Days Before Reminder":** Executes 3 days before the value in `Reminder_Date__c`. Max batch size = 200.

**What it does:** Calls the `Project_Task_Reminder_Notification_Subflow` subflow, passing three inputs from the triggering record: `recordId` ($Record.Id), `ownerId` ($Record.OwnerId), and `taskName` ($Record.Task_Name__c).

---

#### Project_Task_Reminder_Notification_Subflow

| Property | Value |
|---|---|
| API Name | Project_Task_Reminder_Notification_Subflow |
| Label | Project Task Reminder Notification - Subflow |
| Type | Autolaunched Flow (subflow) |
| Run Mode | SystemModeWithoutSharing |
| Status | Active |

**Inputs:** `recordId` (String), `ownerId` (String), `taskName` (String).

**Steps:**
1. Builds a collection variable (`recipientIds`) containing the task owner's Id.
2. Computes the notification body: `"Reminder: " + taskName + " is due soon."`
3. Sends a custom notification via `customNotificationAction`:
   - Notification type: `ProjectTask_Reminder_CNT`
   - Title: "Task Reminder"
   - Body: computed formula above
   - Target record: the Project Task record
   - Recipients: task owner only

Runs in system mode without sharing so the notification can be delivered regardless of the running user's record access at the scheduled execution time.

---

#### Project_Sign_Off_Upload_Document

| Property | Value |
|---|---|
| API Name | Project_Sign_Off_Upload_Document |
| Label | Upload Sign-Off Document |
| Type | Screen Flow |
| Status | Active |

**Input variable:** `recordId` (String) — the Id of the Project Sign Off record. Passed in from the Lightning Record Page.

**Steps:**

1. **Get Sign Off Record** — queries Project_Sign_Off__c by `recordId`, fetching Id, Stage__c, Sign_Off_Status__c, and Opportunity__c.
2. **Get Parent Opportunity** — queries Opportunity by the sign-off's Opportunity__c lookup, fetching Id and Name.
3. **Screen: Upload Sign-Off Document** — displays the sign-off's current Stage and Status, and renders a `forceContent:fileUpload` component attached to the sign-off record. Back navigation is disabled.
4. **Screen: Approve Sign-Off** — displays a confirmation header and a required checkbox ("I confirm I approve this sign-off."). User must check the box to proceed.
5. **Update Sign Off Approved** — sets `Sign_Off_Status__c = "Approved"`, `Approval_Date__c = today`, and `Approved_By__c = current user Id` on the sign-off record.
6. **Update Opportunity Sign Off Complete** — sets `Current_Stage_Sign_Off_Complete__c = true` on the parent Opportunity.

This flow is embedded directly on the Project Sign Off Lightning Record Page via `flowruntime:flowRuntimeForFlexiPage`, so it renders inline on the record without a button modal.

---

### Apex

#### ProjectTaskTrigger

| Property | Value |
|---|---|
| File | `force-app/main/default/triggers/ProjectTaskTrigger.trigger` |
| Object | Project_Task__c |
| Events | before insert, before update |
| Pattern | One trigger per object; no business logic in trigger file |

Delegates to `ProjectTaskTriggerHandler` on every before-insert and before-update event.

---

#### ProjectTaskTriggerHandler

| Property | Value |
|---|---|
| File | `force-app/main/default/classes/ProjectTaskTriggerHandler.cls` |
| Access | `public with sharing` |
| Entry points | `handleBeforeInsert(List<Project_Task__c>)`, `handleBeforeUpdate(List<Project_Task__c>, Map<Id, Project_Task__c>)` |

**validateDueDate:** Iterates the record list and adds a field-level error on `Due_Date__c` if the value is strictly before `Date.today()`. Today's date is valid.

**manageCompletedDate:** Maintains `Completed_Date__c` based on `Status__c` state transitions:

| Context | Old Status__c | New Status__c | Action |
|---|---|---|---|
| Before insert | n/a | Completed | Set `Completed_Date__c` = today |
| Before insert | n/a | not Completed | No change |
| Before update | not Completed | Completed | Set `Completed_Date__c` = today |
| Before update | Completed | not Completed | Clear `Completed_Date__c` to null |
| Before update | no change in Completed state | — | No change |

**Test class:** `ProjectTaskTriggerHandlerTest` — 11 test methods, >= 95% coverage. Covers future/today/past due dates on insert and update, all Completed_Date__c transition scenarios, and the Reminder_Date__c validation rule.

---

### Notifications

#### ProjectTask_Reminder_CNT

| Property | Value |
|---|---|
| API Name | ProjectTask_Reminder_CNT |
| Master Label | Project Task Reminder |
| Desktop | Enabled |
| Mobile | Enabled |
| File | `force-app/main/default/notificationtypes/ProjectTask_Reminder_CNT.notiftype-meta.xml` |

This custom notification type is the delivery channel for the scheduled reminder. The subflow fires it 3 days before the task's `Reminder_Date__c`, targeting the task owner on both desktop and mobile Salesforce apps.

---

## Security

### Permission Sets

All three permission sets apply exclusively to `Project_Task__c`. They cover all six custom fields: Task_Name__c, Status__c, Priority__c, Due_Date__c, Reminder_Date__c, Completed_Date__c.

| Permission Set | API Name | Object Permissions | Field Permissions |
|---|---|---|---|
| Project Task Read Only | ProjectTask_RO_PS | Read | Read on all 6 fields |
| Project Task Read Write | ProjectTask_RW_PS | Create, Read, Edit | Read + Edit on all 6 fields |
| Project Task Delete | ProjectTask_DELETE_PS | Create, Read, Edit, Delete | Read + Edit on all 6 fields |

None of the three permission sets grant `viewAllRecords` or `modifyAllRecords`. Record visibility follows the object's ReadWrite sharing model and the running user's record-level access.

**Note:** No permission sets exist in this repository for Project_Sprint__c, Project_Activity__c, or Project_Sign_Off__c. Access to those objects is managed via profiles or other org-level configuration outside the source directory.

---

### Permission Set Group

| Property | Value |
|---|---|
| API Name | DefaultAdmin_PSG |
| Label | DefaultAdmin PSG |
| File | `force-app/main/default/permissionsetgroups/DefaultAdmin_PSG.permissionsetgroup-meta.xml` |
| Member permission sets | ProjectTask_RW_PS, ProjectTask_DELETE_PS |

Intended for administrative users who need full create/edit/delete access to Project Tasks. Assign this group rather than individual permission sets where combined RW + Delete access is required.

---

### Apex Sharing

`ProjectTaskTriggerHandler` is declared `with sharing` — all DML and queries in the handler respect the running user's record-level sharing. The `Project_Task_Reminder_Notification_Subflow` runs in `SystemModeWithoutSharing` specifically to ensure scheduled notifications can be delivered even when the flow executes outside the owner's session context.

---

## Lightning Record Pages

All four record pages use the `flexipage:recordHomeWithSubheaderTemplateDesktop` template.

### Project_Sprint_Record_Page

| Property | Value |
|---|---|
| Object | Project_Sprint__c |
| File | `force-app/main/default/flexipages/Project_Sprint_Record_Page.flexipage-meta.xml` |

| Region | Component |
|---|---|
| Subheader | Highlights Panel |
| Left | "Sprint Details" field section; "Project Activities" related list (Project_Activities__r) |
| Right | "Activity Metrics" field section — displays Total_Activities__c, Total_Completed_Activities__c, Total_Open_Activities__c |

---

### Project_Activity_Record_Page

| Property | Value |
|---|---|
| Object | Project_Activity__c |
| File | `force-app/main/default/flexipages/Project_Activity_Record_Page.flexipage-meta.xml` |

| Region | Component |
|---|---|
| Subheader | Highlights Panel |
| Left | "Activity Details" field section |
| Right | Chatter feed (forceChatter:feed) |

---

### Project_Sign_Off_Record_Page

| Property | Value |
|---|---|
| Object | Project_Sign_Off__c |
| File | `force-app/main/default/flexipages/Project_Sign_Off_Record_Page.flexipage-meta.xml` |

| Region | Component |
|---|---|
| Subheader | Highlights Panel |
| Left | "Sign Off Details" field section; Upload Sign-Off Document flow (Project_Sign_Off_Upload_Document, inline) |
| Right | "Files" related list (AttachedContentDocuments) |

The flow is embedded inline via `flowruntime:flowRuntimeForFlexiPage` — it renders as a self-contained UI panel on the record page, not as a button that opens a modal.

---

### Opportunity_Project_Record_Page

| Property | Value |
|---|---|
| Object | Opportunity |
| File | `force-app/main/default/flexipages/Opportunity_Project_Record_Page.flexipage-meta.xml` |

| Region | Component |
|---|---|
| Subheader | Path Assistant (runtime_sales_pathassistant:pathAssistant, linear variant) |
| Left | Highlights Panel; "Project Details" field section |
| Right | "Activity Metrics" field section (Total_Sprints__c, Total_Planned_Mandays__c, Total_Actual_Mandays__c); "Project Sprints" related list (Project_Sprints__r); "Project Sign Offs" related list (Project_Sign_Offs__r); "Opportunity Team Members" related list (OpportunityTeamMembers) |

This page is assigned to the `VISEO_Project_Opportunity` record type via `profileActionOverrides` in the Custom Application metadata (`The_7_Deadly_Agents`).

---

## File Locations

```
force-app/main/default/
  objects/
    Opportunity/
      recordTypes/VISEO_Project_Opportunity.recordType-meta.xml
    Project_Sprint__c/
      fields/Sprint_Status__c.field-meta.xml
      fields/Total_Open_Activities__c.field-meta.xml
      validationRules/Prevent_Close_With_Open_Activities.validationRule-meta.xml
    Project_Activity__c/
      fields/Activity_Status__c.field-meta.xml
    Project_Task__c/
      Project_Task__c.object-meta.xml
      fields/Task_Name__c.field-meta.xml
      fields/Status__c.field-meta.xml
      fields/Priority__c.field-meta.xml
      fields/Due_Date__c.field-meta.xml
      fields/Reminder_Date__c.field-meta.xml
      fields/Completed_Date__c.field-meta.xml
      validationRules/Reminder_Not_After_Due_Date.validationRule-meta.xml
  triggers/
    ProjectTaskTrigger.trigger
  classes/
    ProjectTaskTriggerHandler.cls
    ProjectTaskTriggerHandlerTest.cls
  flows/
    Project_Task_After_Save.flow-meta.xml
    Project_Task_Reminder_Notification_Subflow.flow-meta.xml
    Project_Sign_Off_Upload_Document.flow-meta.xml
  notificationtypes/
    ProjectTask_Reminder_CNT.notiftype-meta.xml
  permissionsets/
    ProjectTask_RO_PS.permissionset-meta.xml
    ProjectTask_RW_PS.permissionset-meta.xml
    ProjectTask_DELETE_PS.permissionset-meta.xml
  permissionsetgroups/
    DefaultAdmin_PSG.permissionsetgroup-meta.xml
  flexipages/
    Project_Sprint_Record_Page.flexipage-meta.xml
    Project_Activity_Record_Page.flexipage-meta.xml
    Project_Sign_Off_Record_Page.flexipage-meta.xml
    Opportunity_Project_Record_Page.flexipage-meta.xml
  layouts/
    Opportunity-VISEO Project Opportunity Layout.layout-meta.xml
    Project_Sign_Off__c-Project Sign Off Layout.layout-meta.xml
    Project_Sprint__c-Project Sprint Layout.layout-meta.xml
    Project_Activity__c-Project Activity Layout.layout-meta.xml
  standardValueSets/
    OpportunityStage.standardValueSet-meta.xml
```

---

## Known Corrections (Sprint 2)

Sprint 2 (`feature/2026-06-20-project-delivery-sprint2-corrections`) corrected several gaps found after Sprint 1 deployment. See `docs/sprint2-corrections-2026-06-20.md` for the full list of changes, known gaps, and post-deployment checklist. Summary of what was added:

- Page layouts for all 4 objects (Opportunity, Project Sprint, Project Activity, Project Sign Off)
- Completed and corrected Lightning Record Pages for all 4 objects
- Nine VISEO-specific project stages added to the OpportunityStage StandardValueSet
- "Closed" picklist value added to Sprint_Status__c and Activity_Status__c (see known gaps below)
- Total_Open_Activities__c roll-up filter updated to exclude Closed activities
- Validation rule `Prevent_Close_With_Open_Activities` on Project_Sprint__c

**Outstanding known gaps as of Sprint 2:**

| Gap | Status | Required Action |
|---|---|---|
| "Closed" value in Activity_Status__c metadata file | Not in committed file | Add manually in org or update field file and redeploy |
| "Closed" value in Sprint_Status__c metadata file | Not in committed file | Add manually in org or update field file and redeploy |
| Total_Open_Activities__c — Closed exclusion filter | Third filter item not in committed file | Add after Closed picklist value is confirmed in org |
| Live/AMS stages — won/closed flags | Not set | Update StandardValueSet if business requirement confirmed |
| Opportunity object label rename | Not in objectTranslation file | Apply via Setup or add label/pluralLabel elements and redeploy |
| StageName RecordType picklist override | Not in VISEO_Project_Opportunity metadata | Validate Business Process filters stages; add picklistValues block if needed |
| Lightning Record Page main regions | Minimal metadata | Configure field sections and components in App Builder post-deploy |
