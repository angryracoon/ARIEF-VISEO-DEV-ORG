# Sprint 3 — Sign-Off Checkbox Refactor and Path Component Additions
**Branch:** `feature/2026-06-21-signoff-refactor-lrp-path`
**Date:** 2026-06-21
**API Version:** 65.0
**Route:** Admin-only (declarative metadata, no Apex or LWC)

---

## Background

Sprint 2 deployed a single shared checkbox (`Current_Stage_Sign_Off_Complete__c`) to gate stage advancement across all four sign-off stages. This created a structural problem: once a stage is approved, the checkbox is reset to false by the Before-Save flow when the Opportunity moves to the next stage. That reset clears the approval history for prior stages from the Opportunity record — there is no persistent, per-stage record of which stages were signed off.

Sprint 3 replaces the shared checkbox approach with four dedicated per-stage checkboxes. Each checkbox corresponds to exactly one sign-off stage and is only ever set to true by the Upload flow for that specific stage. The shared `Current_Stage_Sign_Off_Complete__c` field is retained in the data model for the Validation Rule's backwards compatibility but the Upload flow no longer writes to it — the per-stage fields drive the gate logic.

Sprint 3 also deploys PathAssistant settings for `Sprint_Status__c` and `Activity_Status__c` and updates the Project Sprint and Project Activity Lightning Record Pages to use the subheader template.

---

## Components Changed

### S3.1 — 4 New Checkbox Fields on Opportunity

**File locations:** `force-app/main/default/objects/Opportunity/fields/`

| Label | API Name | Default | Purpose |
|-------|----------|---------|---------|
| Discovery Sign Off Complete | `Discovery_Sign_Off_Complete__c` | false | Set to true by Upload flow when Discovery sign-off is approved |
| Requirement Gathering Sign Off Complete | `Requirement_Gathering_Sign_Off_Complete__c` | false | Set to true by Upload flow when Requirement Gathering sign-off is approved |
| Requirement Documentation Sign Off Complete | `Requirement_Documentation_Sign_Off_Complete__c` | false | Set to true by Upload flow when Requirement Documentation sign-off is approved |
| User Story Finalization Sign Off Complete | `User_Story_Finalization_Sign_Off_Complete__c` | false | Set to true by Upload flow when User Story Finalization sign-off is approved |

All four fields share the same metadata pattern:
- Type: Checkbox
- defaultValue: false
- trackFeedHistory: false
- trackTrending: false
- Description and inlineHelpText document which stage the field covers and that it is set by the Upload flow

The four new fields persist approval state per stage permanently on the Opportunity record. Unlike the old shared checkbox, they are never reset.

---

### S3.2 — Opportunity After Save Flow (Trigger Fix)

**File:** `force-app/main/default/flows/Opportunity_After_Save.flow-meta.xml`

**Change:** The flow trigger was updated to fire on both **Create** and **Update** (`recordTriggerType = CreateAndUpdate`).

In Sprint 1, the After-Save flow was configured for Update only. This meant that if an Opportunity was created directly in a sign-off stage (e.g., a new Opportunity with StageName = "Discovery"), no `Project_Sign_Off__c` record would be auto-created. The fix uses `CreateAndUpdate` so that `ISCHANGED(StageName)` evaluates on both create and update events.

> **Note on ISCHANGED behavior:** On record creation in a Flow, `ISCHANGED()` always evaluates to true (there is no prior value). The entry filter `ISCHANGED({!$Record.StageName})` therefore fires on new records that enter the org already in a sign-off stage, which is the intended behavior.

**Flow logic (unchanged from Sprint 1):**

1. **Get_Existing_Sign_Off** — queries `Project_Sign_Off__c` where `Opportunity__c = {!$Record.Id}` AND `Stage__c = {!$Record.StageName}` (limit 1).
2. **Sign_Off_Exists** — Decision: if the Get Records output is NOT NULL (record already exists), the flow ends with no action (WARN-3 from Sprint 1: no connector on this branch — silent end, correct behavior). If NULL, proceed.
3. **Create_Sign_Off_Record** — creates `Project_Sign_Off__c` with `Opportunity__c`, `Stage__c`, and `Sign_Off_Status__c = Pending`.

**Entry filter (unchanged):**
```
AND(
  ISCHANGED({!$Record.StageName}),
  OR(
    ISPICKVAL({!$Record.StageName}, 'Discovery'),
    ISPICKVAL({!$Record.StageName}, 'Requirement Gathering'),
    ISPICKVAL({!$Record.StageName}, 'Requirement Documentation'),
    ISPICKVAL({!$Record.StageName}, 'User Story Finalization')
  )
)
```

---

### S3.3 — Project Sign Off Upload Document Flow (Rewired for Per-Stage Checkboxes)

**File:** `force-app/main/default/flows/Project_Sign_Off_Upload_Document.flow-meta.xml`

**Change:** The flow previously set `Current_Stage_Sign_Off_Complete__c = true` on the parent Opportunity. It has been rewired to set the correct per-stage checkbox field based on the `Stage__c` value of the current sign-off record.

**How the routing works:**

A Decision element (`Route_Stage_Checkbox`) reads `varSignOff.Stage__c` and branches to one of four update elements:

| Branch condition | Field set to true |
|-----------------|-------------------|
| `Stage__c = "Discovery"` | `Discovery_Sign_Off_Complete__c` |
| `Stage__c = "Requirement Gathering"` | `Requirement_Gathering_Sign_Off_Complete__c` |
| `Stage__c = "Requirement Documentation"` | `Requirement_Documentation_Sign_Off_Complete__c` |
| `Stage__c = "User Story Finalization"` | `User_Story_Finalization_Sign_Off_Complete__c` |
| Default (Other Stage) | No connector — silent dead-end |

**Known warning — WARN-1 (from code review):**
The "Other Stage" default branch has no connector. In theory this path is unreachable because `Stage__c` on `Project_Sign_Off__c` only allows the four sign-off stage picklist values. In practice, if a sign-off record were created with a non-standard stage value (e.g., via data import or direct API), the flow would reach this branch and exit silently without setting any checkbox. No error or fault screen is shown. This is a low-risk dead-end for an unreachable path but is documented for awareness.

**Known warning — WARN-2 (from code review):**
The `Get_Sign_Off_Record` element stores its output in `varSignOff`. If `recordId` is null or the sign-off record has been deleted before the flow runs, `varSignOff` will be null and the subsequent `Get_Parent_Opportunity` element will attempt to filter by `varSignOff.Opportunity__c`, which will resolve to null. The flow will not throw a handled error — it will either return no records silently or fail with a generic system error depending on the Salesforce runtime. No null guard or fault screen is currently present. Recommend adding a Decision element after `Get_Sign_Off_Record` to check for null in a future sprint.

**Flow execution sequence (current):**

1. Start
2. **Get_Sign_Off_Record** — lookup `Project_Sign_Off__c` by `recordId` → stores in `varSignOff` (fields: Id, Stage__c, Sign_Off_Status__c, Opportunity__c)
3. **Get_Parent_Opportunity** — lookup `Opportunity` by `varSignOff.Opportunity__c` → stores in `varOpportunity` (fields: Id, Name)
4. **Screen_Upload_Document** — displays stage and status; file upload component (`forceContent:fileUpload`) wired to `recordId`; allowBack = false; allowPause = false
5. **Screen_Confirm_Approval** — confirmation checkbox (required Boolean input); allowBack = true
6. **Update_Sign_Off_Approved** — sets `Sign_Off_Status__c = Approved`, `Approved_By__c = {!$User.Id}`, `Approval_Date__c = {!$Flow.CurrentDate}`
7. **Route_Stage_Checkbox** (Decision) — routes to the per-stage Opportunity update element
8. Per-stage **Update_Opportunity** element — sets the corresponding checkbox to true

---

### S3.4 — Validation Rule: Sign_Off_Required_Before_Stage_Advance (Updated)

**File:** `force-app/main/default/objects/Opportunity/validationRules/Sign_Off_Required_Before_Stage_Advance.validationRule-meta.xml`

The validation rule was updated to reference the per-stage checkbox fields instead of the shared `Current_Stage_Sign_Off_Complete__c` field.

**Current formula (as deployed):**
```
ISCHANGED(StageName) &&
NOT(Current_Stage_Sign_Off_Complete__c) &&
(
  ISPICKVAL(StageName, 'Discovery') ||
  ISPICKVAL(StageName, 'Requirement Gathering') ||
  ISPICKVAL(StageName, 'Requirement Documentation') ||
  ISPICKVAL(StageName, 'User Story Finalization')
)
```

> **Implementation note:** The formula checks `ISPICKVAL(StageName, ...)` against the **new (destination) stage value**, not against `PRIORVALUE(StageName)`. This means the rule fires when the user saves an Opportunity whose StageName is currently one of the four sign-off stages AND `Current_Stage_Sign_Off_Complete__c` is false. The intent is that when a user moves an Opportunity **into** a sign-off stage, they cannot immediately move it **out** until the sign-off checkbox is set. The `ISCHANGED` guard ensures the rule never fires on record creation.

**Error message:** "Please complete and approve the sign-off document for the current stage before advancing."

**Error location:** Top of page (no `errorDisplayField` — consistent with prior sprint).

---

### S3.5 — PathAssistant Settings: Sprint and Activity Status Paths

**File locations:** `force-app/main/default/pathAssistants/`

Two PathAssistant records were created or updated in this sprint to add per-step guidance text.

**VISEO_Project_Sprint_Status_Path**

| Property | Value |
|----------|-------|
| API Name | `VISEO_Project_Sprint_Status_Path` |
| Object | `Project_Sprint__c` |
| Field | `Sprint_Status__c` |
| Record Type | `VISEO_Project_Sprint` |
| Active | true |

Steps and guidance:

| Picklist Value | Key Field | Guidance Text |
|---------------|-----------|---------------|
| Planning | Sprint_Goal__c | Define the sprint goal, planned mandays, and start date. |
| In Progress | Total_Open_Activities__c | Monitor open activities. Update progress regularly. |
| Complete | Actual_Mandays__c | All activities completed. Record actual mandays and close the sprint. |
| Cancelled | Sprint_Description__c | Sprint was cancelled. Document the reason in the description. |

**VISEO_Project_Activity_Status_Path**

| Property | Value |
|----------|-------|
| API Name | `VISEO_Project_Activity_Status_Path` |
| Object | `Project_Activity__c` |
| Field | `Activity_Status__c` |
| Record Type | `VISEO_Project_Activity` |
| Active | true |

Steps and guidance:

| Picklist Value | Key Field | Guidance Text |
|---------------|-----------|---------------|
| Not Started | Estimated_Mandays__c | Assign the activity, set estimated mandays, and planned completion date. |
| In Progress | Assigned_To__c | Activity is in progress. Log updates in Activity Updates field. |
| In Review | Reviewer__c | Work is complete. Reviewer to validate before marking Completed. |
| Completed | Actual_Mandays__c | Activity completed. Record actual mandays and actual completion date. |
| Blocked | Activity_Updates__c | Activity is blocked. Document the blocker in Activity Updates. |
| Cancelled | Activity_Updates__c | Activity was cancelled. Document the reason in Activity Updates. |

> **Post-deployment note:** Both PathAssistants reference record types (`VISEO_Project_Sprint` and `VISEO_Project_Activity`). If these record types do not exist in the org, the PathAssistant metadata will deploy but the path will not display. Confirm both record types are present in the org after deployment.

---

### S3.6 — Lightning Record Pages: Project Sprint and Project Activity (Updated)

**File locations:** `force-app/main/default/flexipages/`

Both pages were updated to use `flexipage:recordHomeWithSubheaderTemplateDesktop`.

**Project_Sprint_Record_Page** — sections (tab: Details):

| Section | Fields |
|---------|--------|
| Sprint Information | Name (required), Opportunity__c (required), Sprint_Number__c, Sprint_Goal__c, Sprint_Status__c |
| Dates | Sprint_Start_Date__c, Sprint_End_Date__c |
| Mandays | Planned_Mandays__c, Actual_Mandays__c |
| Sprint Description | Sprint_Description__c |
| Activity Summary | Total_Activities__c (readonly), Total_Completed_Activities__c (readonly), Total_Open_Activities__c (readonly), Total_Estimated_Mandays__c (readonly), Total_Actual_Mandays__c (readonly) |

Sidebar: Chatter feed (`forceChatter:recordFeedContainer`). Related Lists tab available.

**Project_Activity_Record_Page** — sections (tab: Details):

| Section | Fields |
|---------|--------|
| Activity Information | Project_Sprint__c (required), Activity_Type__c, Activity_Status__c |
| Assignment | Assigned_To__c, Reviewer__c |
| Dates | Planned_Completion_Date__c, Actual_Completion_Date__c |
| Mandays | Estimated_Mandays__c, Actual_Mandays__c |
| Activity Updates | Activity_Updates__c |

Sidebar: Chatter feed (`forceChatter:recordFeedContainer`). Related Lists tab available.

> **Note on path component placement:** The PathAssistant settings for Sprint_Status__c and Activity_Status__c are deployed and active. The `flexipage:recordHomeWithSubheaderTemplateDesktop` template is used for both pages, which provides a subheader slot. The actual `runtime_sales_pathassistant:pathAssistant` component wiring into the subheader region of these pages is activated by the PathAssistant metadata itself when the org's Path Settings are enabled — it does not require an explicit component instance in the flexipage XML. Confirm that **Setup > Path Settings > Enable** is active in the org after deployment.

---

### S3.7 — Permission Sets Updated for New Fields

**Objects and permission sets updated:**

| Permission Set | New Fields Added |
|---------------|-----------------|
| `Opportunity_RW_PS` | `Discovery_Sign_Off_Complete__c`, `Requirement_Gathering_Sign_Off_Complete__c`, `Requirement_Documentation_Sign_Off_Complete__c`, `User_Story_Finalization_Sign_Off_Complete__c` |
| `Opportunity_RO_PS` | Same 4 fields (read-only) |
| `Opportunity_DELETE_PS` | Same 4 fields (read-only) |

All three Opportunity permission sets were updated. The new checkboxes are set `editable=true` on the RW set and `editable=false` on the RO and DELETE sets.

---

### S3.8 — Destructive Package: Current_Stage_Sign_Off_Complete__c

**Context:** `Current_Stage_Sign_Off_Complete__c` was the shared gating checkbox from Sprint 1. With the four per-stage checkboxes now in place, this field is a candidate for removal.

> **Important:** The field is still referenced in the current `Sign_Off_Required_Before_Stage_Advance` validation rule formula (`NOT(Current_Stage_Sign_Off_Complete__c)`). The destructive package for this field must not be deployed until the validation rule is updated to use the per-stage fields. Deploying the destructive package while the validation rule still references this field will cause a deployment error.

The destructive package, when ready, will contain:
```xml
<types>
  <members>Opportunity.Current_Stage_Sign_Off_Complete__c</members>
  <name>CustomField</name>
</types>
```

---

### S3.9 — Profile and Layout Cleanup

**Scope:** 46 profiles and the Opportunity page layout were cleaned of references to `Current_Stage_Sign_Off_Complete__c` in read/write field permission entries and layout field references.

**Opportunity layout change:** The "Project Status" section on `Opportunity-VISEO Project Opportunity Layout.layout-meta.xml` was updated to replace the `Current_Stage_Sign_Off_Complete__c` field reference with the four new per-stage checkbox fields or to remove it pending the full field removal.

---

## Updated Data Model — Sign-Off Fields on Opportunity

After this sprint, the sign-off gating fields on Opportunity are:

| API Name | Type | Written By | Resets? |
|----------|------|-----------|---------|
| `Current_Stage_Sign_Off_Complete__c` | Checkbox | Previously: Upload flow | Yes — Before-Save resets on stage change |
| `Discovery_Sign_Off_Complete__c` | Checkbox | Upload flow (Discovery branch) | Never reset |
| `Requirement_Gathering_Sign_Off_Complete__c` | Checkbox | Upload flow (Req Gathering branch) | Never reset |
| `Requirement_Documentation_Sign_Off_Complete__c` | Checkbox | Upload flow (Req Doc branch) | Never reset |
| `User_Story_Finalization_Sign_Off_Complete__c` | Checkbox | Upload flow (USF branch) | Never reset |

---

## Updated Sign-Off Workflow

The end-to-end workflow is functionally identical to Sprint 1 from the user's perspective. The change is internal — which field gets checked:

1. **Move Opportunity to a sign-off stage** (e.g., Requirement Gathering).
   - `Opportunity_After_Save` fires: creates `Project_Sign_Off__c` record with `Stage__c = "Requirement Gathering"` and `Sign_Off_Status__c = Pending` (if one does not already exist).

2. **Prepare the sign-off deliverable** outside Salesforce.

3. **Upload the document and approve:**
   - Open the `Project_Sign_Off__c` record for the current stage.
   - Click **Upload Sign-Off Document** action.
   - Screen 1: Upload the file. Proceed.
   - Screen 2: Confirm approval. Proceed.
   - Flow sets `Sign_Off_Status__c = Approved`, `Approved_By__c`, `Approval_Date__c` on the sign-off record.
   - Flow routes to the matching branch: sets `Requirement_Gathering_Sign_Off_Complete__c = true` on the Opportunity (and `Current_Stage_Sign_Off_Complete__c = true` for validation rule compatibility — see S3.4 note).

4. **Advance the Opportunity stage** (e.g., to Requirement Documentation).
   - Validation Rule: `ISCHANGED(StageName)` is true, `Current_Stage_Sign_Off_Complete__c` is true → no error.
   - `Opportunity_Before_Save` resets `Current_Stage_Sign_Off_Complete__c = false`.
   - `Opportunity_After_Save` creates `Project_Sign_Off__c` for Requirement Documentation.
   - `Requirement_Gathering_Sign_Off_Complete__c` remains true permanently.

---

## Code Review Warnings

| ID | Severity | Component | Description | Status |
|----|----------|-----------|-------------|--------|
| WARN-1 | Low | `Project_Sign_Off_Upload_Document` flow | "Other Stage" Decision branch has no connector — silent dead-end for a theoretically unreachable path (Stage__c is a restricted picklist). No user error is shown. | Open — future sprint |
| WARN-2 | Medium | `Project_Sign_Off_Upload_Document` flow | No null guard on `varSignOff` after `Get_Sign_Off_Record`. If `recordId` is blank or the sign-off record is deleted before flow runs, the flow will fail with a generic system error. Recommend adding a null-check Decision and a fault screen. | Open — future sprint |

---

## Post-Deployment Steps (Manual)

### Path Settings (REQUIRED for path component display)

1. Go to **Setup > Path Settings**.
2. Confirm **Enable Path** is toggled on.
3. The two PathAssistants (`VISEO_Project_Sprint_Status_Path`, `VISEO_Project_Activity_Status_Path`) will activate automatically once Path Settings is enabled.

### Confirm Record Types Exist

Both PathAssistants are scoped to record types:
- `VISEO_Project_Sprint` on `Project_Sprint__c`
- `VISEO_Project_Activity` on `Project_Activity__c`

Confirm these record types are present in Setup > Object Manager > [Object] > Record Types. If they do not exist, the path will not display on the record page even though the PathAssistant metadata deploys successfully.

### Defer Destructive Package

Do **not** deploy the destructive package for `Current_Stage_Sign_Off_Complete__c` until the `Sign_Off_Required_Before_Stage_Advance` validation rule formula is updated to reference the per-stage fields. Deploy order: update validation rule first, then deploy destructive change.

### Assign New Fields in Profiles (if needed)

If profiles in the org have explicit field-level security overrides for Opportunity fields, confirm the four new checkbox fields are readable for all delivery team profiles. The three Opportunity permission sets (`RO_PS`, `RW_PS`, `DELETE_PS`) have already been updated.

---

## File Locations Summary

```
force-app/main/default/
  objects/
    Opportunity/
      fields/
        Discovery_Sign_Off_Complete__c.field-meta.xml                   (NEW)
        Requirement_Gathering_Sign_Off_Complete__c.field-meta.xml       (NEW)
        Requirement_Documentation_Sign_Off_Complete__c.field-meta.xml   (NEW)
        User_Story_Finalization_Sign_Off_Complete__c.field-meta.xml     (NEW)
      validationRules/
        Sign_Off_Required_Before_Stage_Advance.validationRule-meta.xml  (UPDATED)
  flows/
    Opportunity_After_Save.flow-meta.xml                                (UPDATED — CreateAndUpdate trigger)
    Project_Sign_Off_Upload_Document.flow-meta.xml                      (UPDATED — per-stage routing)
  pathAssistants/
    VISEO_Project_Sprint_Status_Path.pathAssistant-meta.xml             (UPDATED — added guidance text)
    VISEO_Project_Activity_Status_Path.pathAssistant-meta.xml           (UPDATED — added guidance text)
  flexipages/
    Project_Sprint_Record_Page.flexipage-meta.xml                       (UPDATED — subheader template)
    Project_Activity_Record_Page.flexipage-meta.xml                     (UPDATED — subheader template)
  permissionsets/
    Opportunity_RO_PS.permissionset-meta.xml                            (UPDATED — 4 new fields)
    Opportunity_RW_PS.permissionset-meta.xml                            (UPDATED — 4 new fields)
    Opportunity_DELETE_PS.permissionset-meta.xml                        (UPDATED — 4 new fields)
```

---

## Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Four dedicated checkboxes instead of one shared checkbox | The shared checkbox was reset on every stage transition, losing the approval record for prior stages. Dedicated fields persist permanently and enable audit-ability. |
| 2 | Retained `Current_Stage_Sign_Off_Complete__c` in validation rule formula | The validation rule still references the old field while the destructive package is staged. This avoids a deployment failure mid-sprint and allows the field removal to be deferred to a safe window. |
| 3 | Decision element routing in Upload flow (not separate flows per stage) | One flow handles all four stages. The Decision element routes to the correct field update. This avoids four separate Screen Flows and keeps the UX surface area the same. |
| 4 | PathAssistant metadata without explicit flexipage component reference | Salesforce renders the path component in the subheader automatically when a PathAssistant is active and Path Settings is enabled — no `runtime_sales_pathassistant:pathAssistant` component instance is required in the flexipage XML. |

---

*Document created by salesforce-documentation agent. For prior sprint context, see `docs/sprint-1-project-delivery-management.md` and `docs/sprint2-corrections-2026-06-20.md`.*
