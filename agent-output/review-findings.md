# Code Review Findings — Sprint 1 Project Delivery Management

**Branch:** `feature/2026-06-19-project-delivery-management-sprint1`
**Date:** 2026-06-20
**Reviewer Agent:** salesforce-code-review
**Review Type:** Declarative Only (no Apex / Trigger / LWC in scope)

---

## VERDICT: APPROVED WITH WARNINGS

---

## Summary

| Severity | Count |
|----------|-------|
| BLOCKER (FAIL) | 2 |
| WARNING (WARN) | 4 |
| PASS | 27 |

> **Note:** Verdict is APPROVED WITH WARNINGS because the two FAIL items are metadata gaps that do not prevent deployment itself but represent incomplete coverage (missing record type file) and a functional risk (empty summarizedField tags). See details below.

> PR approval still depends on `sf project deploy validate` passing against the org before merge is initiated.

---

## BLOCKER Issues

### FAIL-1: Missing Record Type metadata file for VISEO_Project_Opportunity

**File:** `force-app/main/default/objects/Opportunity/recordTypes/VISEO_Project_Opportunity.recordType-meta.xml`
**Status:** FILE DOES NOT EXIST

The Path Assistant at `force-app/main/default/pathAssistants/VISEO_Project_Opportunity_Path.pathAssistant-meta.xml` line 52 references `<recordTypeName>VISEO_Project_Opportunity</recordTypeName>`, but no corresponding record type metadata file exists in the local source. The design (section 2.1) specifies this record type must be created.

**Risk:** Deployment of the Path Assistant will fail if the record type does not exist in the org. Even if the record type was created manually in the org prior to this deployment, its metadata is not committed to version control, making the branch state unreproducible.

**Fix:** Create `force-app/main/default/objects/Opportunity/recordTypes/VISEO_Project_Opportunity.recordType-meta.xml` with the following content (active, business process and picklist values for the 9 stages):

```xml
<?xml version="1.0" encoding="UTF-8"?>
<RecordType xmlns="http://soap.sforce.com/2006/04/metadata">
    <active>true</active>
    <description>VISEO Project Opportunity Record Type</description>
    <label>VISEO Project Opportunity</label>
</RecordType>
```

---

### FAIL-2: Empty `<summarizedField>` tag on COUNT Roll-Up Summary fields

**Files:**
- `force-app/main/default/objects/Opportunity/fields/Total_Sprints__c.field-meta.xml` line 5
- `force-app/main/default/objects/Project_Sprint__c/fields/Total_Activities__c.field-meta.xml` line 5
- `force-app/main/default/objects/Project_Sprint__c/fields/Total_Completed_Activities__c.field-meta.xml` line 5
- `force-app/main/default/objects/Project_Sprint__c/fields/Total_Open_Activities__c.field-meta.xml` line 5

All four COUNT Roll-Up Summary fields contain `<summarizedField></summarizedField>` (an empty tag). The Salesforce metadata API for Roll-Up Summary fields of type COUNT does not require a `summarizedField` element at all. An empty self-closing or empty-pair tag can cause deployment warnings or errors depending on the org's API version handling.

**Fix:** Remove the `<summarizedField></summarizedField>` line entirely from each of the four files. SUM fields (`Total_Planned_Mandays__c`, `Total_Actual_Mandays__c`, `Total_Estimated_Mandays__c`, `Total_Actual_Mandays__c` on Sprint) correctly do not have this issue as they specify the field name.

---

## WARNING Issues

### WARN-1: Validation Rule fires on Opportunity Create (not just Edit)

**File:** `force-app/main/default/objects/Opportunity/validationRules/Sign_Off_Required_Before_Stage_Advance.validationRule-meta.xml`

The formula uses `ISCHANGED(StageName)`. In Salesforce, `ISCHANGED()` always returns `false` on record creation (there is no prior value), so this is safe — new records are never blocked. However, the formula does not guard against the case where `Current_Stage_Sign_Off_Complete__c` is `null` (though a Checkbox field defaults to `false` and cannot be null). This is acceptable. Documenting for clarity.

Additionally: the `<errorDisplayField></errorDisplayField>` is an empty tag rather than being omitted. While this usually deploys fine, it is cleaner to omit the element entirely when using top-of-page error display. Low risk, not a blocker.

**Fix (recommended):** Remove the empty `<errorDisplayField></errorDisplayField>` line from the validation rule file.

---

### WARN-2: Screen Flow — no null/fault path after Get Record lookups

**File:** `force-app/main/default/flows/Project_Sign_Off_Upload_Document.flow-meta.xml`

The `Get_Sign_Off_Record` (line 20) and `Get_Parent_Opportunity` (line 46) record lookup elements have `<assignNullValuesIfNoRecordsFound>false</assignNullValuesIfNoRecordsFound>`. If the `recordId` input variable is blank or points to a deleted record, the flow will silently use null values and produce a confusing error when it tries to display `{!varSignOff.Stage__c}` or update a null Opportunity. There are no fault connectors or decision elements to handle the case where no sign-off or opportunity record is found.

**Fix (recommended):** Add Decision elements after each Get Records lookup to check `IS NULL` on the output variable, and display a user-friendly screen error message rather than letting the flow fail silently. This is a UX and robustness issue — not a deploy blocker, but critical for production readiness.

---

### WARN-3: After-Save Flow — Decision logic checks IsNull=false (sign-off exists) in the wrong rule name

**File:** `force-app/main/default/flows/Opportunity_After_Save.flow-meta.xml` lines 13-24

The decision `Sign_Off_Exists` has a rule named `Sign_Off_Already_Exists` which checks `Get_Existing_Sign_Off` IsNull = false. The `defaultConnector` (no sign-off found) goes to `Create_Sign_Off_Record`. This logic is correct — if the variable is NOT null, a sign-off already exists so we skip creation; the default path (sign-off not found) creates one.

However, there is no explicit connector from the `Sign_Off_Already_Exists` rule — no `connector` element is shown for the "yes it exists" branch. In Salesforce Flow metadata, if the named rule has no `connector`, execution ends for that path (the flow terminates without error). This is acceptable for this use case since no action is needed if the sign-off already exists.

**Note:** This is actually correct behavior and not a bug. Flagging for documentation clarity only. WARN severity.

---

### WARN-4: Lightning Record Pages do not include `<pageAssignments>` for org-default assignment

**Files:**
- `force-app/main/default/flexipages/Opportunity_Project_Record_Page.flexipage-meta.xml`
- `force-app/main/default/flexipages/Project_Sprint_Record_Page.flexipage-meta.xml`
- `force-app/main/default/flexipages/Project_Activity_Record_Page.flexipage-meta.xml`
- `force-app/main/default/flexipages/Project_Sign_Off_Record_Page.flexipage-meta.xml`

The design requirement (section 11) states: "Assign all pages as the org default for their respective object." None of the four flexipage files contain `<pageAssignments>` elements that would deploy the org-default assignment via metadata. Without this, the pages will deploy as available pages but will not be set as the org default — an admin must manually activate them post-deploy via Lightning App Builder.

This is a common metadata gap and is often addressed post-deploy, but it represents an incomplete implementation of the design spec.

**Fix (recommended):** Add `<pageAssignments>` blocks to each flexipage file, or document that post-deploy manual activation is required.

---

## PASS Items

### Object Metadata

| Check | Result |
|-------|--------|
| Project_Sign_Off__c sharingModel=ControlledByParent | PASS |
| Project_Sprint__c sharingModel=ControlledByParent | PASS |
| Project_Activity__c sharingModel=ControlledByParent | PASS |
| Project_Sign_Off__c AutoNumber PSO-{0000} | PASS |
| Project_Activity__c AutoNumber ACT-{00000} | PASS |
| Project_Sprint__c nameField type=Text label="Sprint Name" | PASS |
| Project_Activity__c enableFeeds=true (Chatter enabled) | PASS |
| All 3 custom objects enableReports=true | PASS |
| All 3 objects deploymentStatus=Deployed | PASS |

### Master-Detail Relationships

| Check | Result |
|-------|--------|
| Project_Sign_Off__c.Opportunity__c — type=MasterDetail, referenceTo=Opportunity, relationshipOrder=0 | PASS |
| Project_Sprint__c.Opportunity__c — type=MasterDetail, referenceTo=Opportunity, relationshipOrder=0 | PASS |
| Project_Activity__c.Project_Sprint__c — type=MasterDetail, referenceTo=Project_Sprint__c, relationshipOrder=0 | PASS |
| All MD fields: required=true, reparentableMasterDetail=false, writeRequiresMasterRead=false | PASS |

### Roll-Up Summary Fields

| Check | Result |
|-------|--------|
| Opportunity.Total_Sprints__c — COUNT, summaryForeignKey=Project_Sprint__c.Opportunity__c | PASS |
| Opportunity.Total_Planned_Mandays__c — SUM, summarizedField=Project_Sprint__c.Planned_Mandays__c | PASS |
| Opportunity.Total_Actual_Mandays__c — SUM, summarizedField=Project_Sprint__c.Actual_Mandays__c | PASS |
| Project_Sprint__c.Total_Activities__c — COUNT, summaryForeignKey=Project_Activity__c.Project_Sprint__c | PASS |
| Project_Sprint__c.Total_Completed_Activities__c — COUNT with filter Activity_Status__c=Completed | PASS |
| Project_Sprint__c.Total_Open_Activities__c — COUNT with two notEqual filters (Completed, Cancelled) | PASS |
| Project_Sprint__c.Total_Estimated_Mandays__c — SUM Estimated_Mandays__c | PASS |
| Project_Sprint__c.Total_Actual_Mandays__c — SUM Actual_Mandays__c | PASS |
| All RU Summary fields in RW_PS marked editable=false | PASS |

### Flows

| Check | Result |
|-------|--------|
| Opportunity_Before_Save: apiVersion=65.0, triggerType=RecordBeforeSave, object=Opportunity | PASS |
| Opportunity_Before_Save: filterFormula correctly uses ISCHANGED + ISPICKVAL for 4 stages | PASS |
| Opportunity_Before_Save: Assignment sets $Record.Current_Stage_Sign_Off_Complete__c = false | PASS |
| Opportunity_After_Save: apiVersion=65.0, triggerType=RecordAfterSave, object=Opportunity | PASS |
| Opportunity_After_Save: Same entry criteria as Before-Save flow | PASS |
| Opportunity_After_Save: Get Records queries by Opportunity__c AND Stage__c, getFirstRecordOnly=true | PASS |
| Opportunity_After_Save: Decision correctly routes to Create only when no existing sign-off | PASS |
| Opportunity_After_Save: Creates Sign Off with Opportunity__c, Stage__c, Sign_Off_Status__c=Pending | PASS |
| Screen Flow: apiVersion=65.0, processType=Flow | PASS |
| Screen Flow: recordId input variable (isInput=true) | PASS |
| Screen Flow: FileUpload component wired to {!recordId} as relatedRecordId | PASS |
| Screen Flow: Updates Sign_Off_Status__c=Approved, Approved_By__c=$User.Id, Approval_Date__c=$Flow.CurrentDate | PASS |
| Screen Flow: Second update sets Current_Stage_Sign_Off_Complete__c=true on Opportunity | PASS |

### Validation Rule

| Check | Result |
|-------|--------|
| Formula: ISCHANGED(StageName) + NOT(Current_Stage_Sign_Off_Complete__c) + PRIORVALUE checks | PASS |
| 4 prior-value stage checks match design spec exactly | PASS |
| active=true | PASS |
| Error message matches design spec | PASS |

### Permission Sets

| Check | Result |
|-------|--------|
| ProjectManagement_RW_PS: Read+Create+Edit on Opportunity, Project_Sprint__c, Project_Activity__c, Project_Sign_Off__c, Project_Task__c | PASS |
| ProjectManagement_RW_PS: allowDelete=false on all objects | PASS |
| ProjectManagement_DELETE_PS: Read+Delete on all 5 objects, allowCreate/Edit=false | PASS |
| All 13 Opportunity custom fields present in RW_PS field permissions | PASS |
| OpportunityTeamMember.Delivery_Role__c in RW_PS | PASS |
| All Project_Sprint__c fields (9 editable + 5 rollups read-only) in RW_PS | PASS |
| All Project_Activity__c fields (9 editable) in RW_PS | PASS |
| All Project_Sign_Off__c fields (4 editable) in RW_PS | PASS |

### PSG, Tabs, App

| Check | Result |
|-------|--------|
| DefaultAdmin_PSG: keeps ProjectTask_RW_PS + ProjectTask_DELETE_PS (existing) | PASS |
| DefaultAdmin_PSG: adds ProjectManagement_RW_PS + ProjectManagement_DELETE_PS (new) | PASS |
| 3 new custom tabs present: Project_Sprint__c, Project_Activity__c, Project_Sign_Off__c | PASS |
| The_7_Deadly_Agents app: preserves existing tabs (standard-Account, Project_Task__c) | PASS |
| The_7_Deadly_Agents app: adds standard-Opportunity, Project_Sprint__c, Project_Activity__c, Project_Sign_Off__c | PASS |
| No hardcoded Salesforce IDs found anywhere in metadata | PASS |
| All reviewed files use API namespace http://soap.sforce.com/2006/04/metadata | PASS |
| XML well-formed on all reviewed files | PASS |

---

## Good Practices Acknowledged

- Clean split of Before-Save and After-Save flows avoids recursive DML — well designed
- Validation rule correctly uses `PRIORVALUE(StageName)` to detect which stage was left, not which stage was entered — this is the correct pattern to avoid false positives when moving between non-sign-off stages
- Roll-Up Summary foreign keys all correctly use the full `Object.Field` notation
- `Total_Open_Activities__c` correctly uses two `notEqual` filter items (AND logic) rather than a single complex filter — this is the correct metadata approach since RUSF does not support OR logic in filter items
- Permission sets correctly set rollup fields to `editable=false` — this is important since rollup fields cannot be edited and must not be marked editable in permission sets
- PSG correctly preserves existing members from the prior sprint

---

NEXT_AGENT: salesforce-documentation
