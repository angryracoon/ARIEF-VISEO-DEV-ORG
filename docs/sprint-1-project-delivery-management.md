# Sprint 1 — Project Delivery Management

**Branch:** `feature/2026-06-19-project-delivery-management-sprint1`
**Date:** 2026-06-20
**API Version:** 65.0
**Implementation type:** Declarative only (no Apex / Trigger / LWC)
**Code review verdict:** APPROVED WITH WARNINGS (2 blockers fixed pre-deploy, 4 warnings documented below)

---

## 1. Overview and Objective

This sprint introduces a Project Delivery Management layer on top of the existing VISEO Salesforce org. The objective is to give delivery teams a structured way to track project opportunities through defined delivery stages, manage sprints and activities within each project, enforce sign-off gates before stage advancement, and capture approval documents via an in-app screen flow.

The implementation is entirely declarative — no custom Apex or LWC was written. All business logic runs through Record-Triggered Flows, a Screen Flow, a Validation Rule, and Roll-Up Summary fields.

---

## 2. Data Model

```
Opportunity (Standard Object — VISEO_Project_Opportunity Record Type)
│
│  13 custom project fields (scope, dates, mandays, health, methodology)
│  3 Roll-Up Summary fields from Project_Sprint__c
│  Checkbox: Current_Stage_Sign_Off_Complete__c  (gating field)
│  Validation Rule: Sign_Off_Required_Before_Stage_Advance
│
├─── Project_Sign_Off__c  (Master-Detail → Opportunity)
│       PSO-{0000} auto-number
│       Stage__c (Discovery / Req Gathering / Req Doc / User Story Fin.)
│       Sign_Off_Status__c (Pending → Approved / Rejected)
│       Approved_By__c (User lookup)
│       Approval_Date__c (Date)
│       [Salesforce Files — ContentDocument attached via Screen Flow]
│
└─── Project_Sprint__c  (Master-Detail → Opportunity)
         Sprint Name (text), Sprint_Number__c, status, dates, mandays
         5 Roll-Up Summary fields from Project_Activity__c
         │
         └─── Project_Activity__c  (Master-Detail → Project_Sprint__c)
                  ACT-{00000} auto-number
                  Activity_Type__c, Activity_Status__c
                  Assigned_To__c, Reviewer__c (User lookups)
                  Estimated and Actual Mandays, Dates
                  Activity_Updates__c (LongText)
                  Chatter feed enabled
```

### Relationship rules

- `Project_Sign_Off__c` and `Project_Sprint__c` are children of Opportunity via **Master-Detail** — they inherit Opportunity sharing and are deleted when the parent Opportunity is deleted.
- `Project_Activity__c` is a child of `Project_Sprint__c` via **Master-Detail** — it inherits Sprint sharing and is deleted when the parent Sprint is deleted.
- All three custom objects use `sharingModel = ControlledByParent` (set declaratively in object metadata).

---

## 3. Objects and Fields

### 3.1 Opportunity (Standard Object)

**Record Type added:** `VISEO_Project_Opportunity` (active)

**Stage path:** `VISEO_Project_Opportunity_Path` — 9 ordered stages:

| # | Stage Name |
|---|-----------|
| 1 | Discovery |
| 2 | Requirement Gathering |
| 3 | Requirement Documentation |
| 4 | User Story Finalization |
| 5 | In Development |
| 6 | QA |
| 7 | UAT |
| 8 | Live |
| 9 | AMS |

**Custom fields added:**

| Label | API Name | Type | Notes |
|-------|----------|------|-------|
| Project Scope | `Project_Scope__c` | LongTextArea | 32768 chars, 6 visible lines |
| Project Description | `Project_Description__c` | LongTextArea | 32768 chars, 6 visible lines |
| Start Date | `Start_Date__c` | Date | — |
| Planned Go-Live Date | `Planned_Go_Live_Date__c` | Date | — |
| Actual Go-Live Date | `Actual_Go_Live_Date__c` | Date | — |
| Planned Mandays | `Planned_Mandays__c` | Number | Precision 8, Scale 2 |
| Actual Mandays | `Actual_Mandays__c` | Number | Precision 8, Scale 2 |
| Project Health | `Project_Health__c` | Picklist | On Track; At Risk; Off Track |
| Delivery Methodology | `Delivery_Methodology__c` | Picklist | Agile; Waterfall; Hybrid |
| Current Stage Sign Off Complete | `Current_Stage_Sign_Off_Complete__c` | Checkbox | Default false — gating field for validation rule and flows |
| Total Sprints | `Total_Sprints__c` | Roll-Up Summary | COUNT all `Project_Sprint__c` children |
| Total Planned Mandays | `Total_Planned_Mandays__c` | Roll-Up Summary | SUM `Project_Sprint__c.Planned_Mandays__c` |
| Total Actual Mandays | `Total_Actual_Mandays__c` | Roll-Up Summary | SUM `Project_Sprint__c.Actual_Mandays__c` |

### 3.2 OpportunityTeamMember (Standard Object)

**Custom field added:**

| Label | API Name | Type | Picklist Values |
|-------|----------|------|----------------|
| Delivery Role | `Delivery_Role__c` | Picklist | Project Manager; Solution Architect; Technical Architect; Business Analyst; Functional Consultant; Technical Consultant; Developer; QA Engineer; Scrum Master; AMS Consultant; Support Consultant; Other |

### 3.3 Project_Sign_Off__c

**Object properties:**

| Property | Value |
|----------|-------|
| API Name | `Project_Sign_Off__c` |
| Name field | Auto Number — `PSO-{0000}` |
| Sharing model | ControlledByParent |
| Chatter | Disabled |
| Reports | Enabled |

**Fields:**

| Label | API Name | Type | Notes |
|-------|----------|------|-------|
| Opportunity | `Opportunity__c` | Master-Detail (Opportunity) | Required; relationshipOrder=0 |
| Stage | `Stage__c` | Picklist | Discovery; Requirement Gathering; Requirement Documentation; User Story Finalization |
| Sign Off Status | `Sign_Off_Status__c` | Picklist | Pending (default); Approved; Rejected |
| Approved By | `Approved_By__c` | Lookup (User) | Populated by Screen Flow |
| Approval Date | `Approval_Date__c` | Date | Populated by Screen Flow |

> Document attachment: the actual sign-off document is stored as a Salesforce File (ContentDocument) attached to the `Project_Sign_Off__c` record. The Screen Flow uses a standard File Upload component — no custom file field is needed.

### 3.4 Project_Sprint__c

**Object properties:**

| Property | Value |
|----------|-------|
| API Name | `Project_Sprint__c` |
| Name field | Text — label "Sprint Name" |
| Sharing model | ControlledByParent |
| Reports | Enabled |

**Fields:**

| Label | API Name | Type | Notes |
|-------|----------|------|-------|
| Opportunity | `Opportunity__c` | Master-Detail (Opportunity) | Required; relationshipOrder=0 |
| Sprint Number | `Sprint_Number__c` | Number | Precision 8, Scale 0 |
| Sprint Goal | `Sprint_Goal__c` | Text | 255 chars |
| Sprint Description | `Sprint_Description__c` | LongTextArea | 32768 chars, 4 visible lines |
| Sprint Start Date | `Sprint_Start_Date__c` | Date | — |
| Sprint End Date | `Sprint_End_Date__c` | Date | — |
| Planned Mandays | `Planned_Mandays__c` | Number | Precision 8, Scale 2 |
| Actual Mandays | `Actual_Mandays__c` | Number | Precision 8, Scale 2 |
| Sprint Status | `Sprint_Status__c` | Picklist | Planning (default); In Progress; Complete; Cancelled |
| Total Activities | `Total_Activities__c` | Roll-Up Summary | COUNT all `Project_Activity__c` children |
| Total Completed Activities | `Total_Completed_Activities__c` | Roll-Up Summary | COUNT where `Activity_Status__c = Completed` |
| Total Open Activities | `Total_Open_Activities__c` | Roll-Up Summary | COUNT where `Activity_Status__c != Completed` AND `!= Cancelled` |
| Total Estimated Mandays | `Total_Estimated_Mandays__c` | Roll-Up Summary | SUM `Estimated_Mandays__c` |
| Total Actual Mandays | `Total_Actual_Mandays__c` | Roll-Up Summary | SUM `Actual_Mandays__c` |

### 3.5 Project_Activity__c

**Object properties:**

| Property | Value |
|----------|-------|
| API Name | `Project_Activity__c` |
| Name field | Auto Number — `ACT-{00000}` |
| Sharing model | ControlledByParent |
| Chatter (Feed Tracking) | Enabled |
| Reports | Enabled |

**Fields:**

| Label | API Name | Type | Notes |
|-------|----------|------|-------|
| Project Sprint | `Project_Sprint__c` | Master-Detail (Project_Sprint__c) | Required; relationshipOrder=0 |
| Activity Type | `Activity_Type__c` | Picklist | Development; QA; BA; Design; DevOps; Other |
| Activity Status | `Activity_Status__c` | Picklist | Not Started (default); In Progress; In Review; Completed; Blocked; Cancelled |
| Assigned To | `Assigned_To__c` | Lookup (User) | — |
| Reviewer | `Reviewer__c` | Lookup (User) | — |
| Estimated Mandays | `Estimated_Mandays__c` | Number | Precision 8, Scale 2 |
| Actual Mandays | `Actual_Mandays__c` | Number | Precision 8, Scale 2 |
| Planned Completion Date | `Planned_Completion_Date__c` | Date | — |
| Actual Completion Date | `Actual_Completion_Date__c` | Date | — |
| Activity Updates | `Activity_Updates__c` | LongTextArea | 32768 chars, 4 visible lines |

---

## 4. Flow Logic

### 4.1 Opportunity Before Save — `Opportunity_Before_Save`

**Type:** Record-Triggered, Before Save (Create and Edit)

**Entry criteria:** `StageName IS CHANGED` AND new value is one of: Discovery, Requirement Gathering, Requirement Documentation, User Story Finalization.

**What it does:** Sets `Current_Stage_Sign_Off_Complete__c = false` on the in-memory `$Record` before the record is saved. This resets the sign-off gate whenever a project opportunity moves into one of the four stages that require a sign-off. The Before-Save context means no separate DML is needed — the field is stamped as part of the original save transaction.

**Why split from After-Save:** Writing to `$Record` is only possible in a Before-Save flow. The After-Save flow handles record creation (DML), which is not allowed in Before-Save.

### 4.2 Opportunity After Save — `Opportunity_After_Save`

**Type:** Record-Triggered, After Save (Create and Edit)

**Entry criteria:** Same as Before Save — `StageName IS CHANGED` AND new value is one of the four sign-off stages.

**What it does:**

1. **Get Records:** Queries `Project_Sign_Off__c` where `Opportunity__c = {!$Record.Id}` AND `Stage__c = {!$Record.StageName}` (limit 1, getFirstRecordOnly = true).
2. **Decision — Sign_Off_Exists:** If the Get Records output IS NOT NULL, a sign-off record for this stage already exists — execution ends (no duplicate created). If the output IS NULL (default path), proceed to step 3.
3. **Create Record:** Creates a new `Project_Sign_Off__c` with `Opportunity__c = {!$Record.Id}`, `Stage__c = {!$Record.StageName}`, `Sign_Off_Status__c = Pending`.

**Result:** Every time an Opportunity enters one of the four tracked stages, exactly one `Project_Sign_Off__c` record in Pending status is guaranteed to exist for that stage.

### 4.3 Screen Flow — `Project_Sign_Off_Upload_Document`

**Type:** Screen Flow (user-launched via Quick Action on Project Sign Off record page)

**Input variable:** `recordId` (Text, available for input) — the Id of the `Project_Sign_Off__c` record.

**Steps:**

1. **Get_Sign_Off_Record:** Looks up `Project_Sign_Off__c` by `{!recordId}`.
2. **Get_Parent_Opportunity:** Looks up the parent Opportunity using `varSignOff.Opportunity__c`.
3. **Screen 1 — Upload Document:**
   - Displays the sign-off stage and current status.
   - Provides a File Upload component wired to `{!recordId}` as the related record — the uploaded file is stored as a Salesforce File attached to the sign-off record.
   - Required confirmation checkbox: "I have uploaded the required sign-off document."
4. **Screen 2 — Confirm Approval:**
   - Displays a confirmation message.
   - Required confirmation checkbox: "I confirm I approve this sign-off."
5. **Update `Project_Sign_Off__c`:** Sets `Sign_Off_Status__c = Approved`, `Approved_By__c = {!$User.Id}`, `Approval_Date__c = {!$Flow.CurrentDate}`.
6. **Update Opportunity:** Sets `Current_Stage_Sign_Off_Complete__c = true` on the parent Opportunity — this unlocks stage advancement.

### 4.4 Validation Rule — `Sign_Off_Required_Before_Stage_Advance`

**Object:** Opportunity

**Formula:**
```
ISCHANGED(StageName) &&
NOT(Current_Stage_Sign_Off_Complete__c) &&
(
  ISPICKVAL(PRIORVALUE(StageName), "Discovery") ||
  ISPICKVAL(PRIORVALUE(StageName), "Requirement Gathering") ||
  ISPICKVAL(PRIORVALUE(StageName), "Requirement Documentation") ||
  ISPICKVAL(PRIORVALUE(StageName), "User Story Finalization")
)
```

**Error message:** "Please complete and approve the sign-off document for the current stage before advancing."

**Behavior:** Fires only when the user attempts to save an Opportunity with a changed `StageName`, the prior value was one of the four sign-off stages, and `Current_Stage_Sign_Off_Complete__c` is false. `ISCHANGED()` always returns false on record creation, so new records are never blocked. `Current_Stage_Sign_Off_Complete__c` is a Checkbox and defaults to false — it cannot be null.

---

## 5. Sign-Off Workflow (Step by Step)

This is the end-to-end sequence a delivery team follows when advancing an Opportunity through a sign-off stage:

1. **Move Opportunity to a sign-off stage** (e.g., Discovery).
   - `Opportunity_Before_Save` fires: sets `Current_Stage_Sign_Off_Complete__c = false`.
   - `Opportunity_After_Save` fires: creates `Project_Sign_Off__c` record with `Stage__c = Discovery` and `Sign_Off_Status__c = Pending`.

2. **Prepare the sign-off document** — create the required deliverable outside Salesforce (e.g., a Discovery report).

3. **Upload the document and approve:**
   - Open the `Project_Sign_Off__c` record for the current stage.
   - Click the **Upload Sign-Off Document** action button.
   - Screen 1: Upload the document file. Check the confirmation box.
   - Screen 2: Review the approval statement. Check the confirmation box.
   - The Screen Flow updates the sign-off record (`Sign_Off_Status__c = Approved`, `Approved_By__c`, `Approval_Date__c`) and sets `Current_Stage_Sign_Off_Complete__c = true` on the Opportunity.

4. **Advance the Opportunity stage** (e.g., to Requirement Gathering).
   - The Validation Rule checks: StageName is changed, prior value was Discovery, `Current_Stage_Sign_Off_Complete__c = true` — no error is thrown.
   - The Before-Save flow resets `Current_Stage_Sign_Off_Complete__c = false` for the new stage.
   - The After-Save flow creates a new `Project_Sign_Off__c` for the Requirement Gathering stage.
   - Repeat from step 2.

5. **Stages that do not require sign-off** (In Development, QA, UAT, Live, AMS):
   - The Validation Rule's `PRIORVALUE` check only covers the four sign-off stages — advancing from or between non-sign-off stages is not blocked.

---

## 6. Security Model

### 6.1 Organisation-Wide Defaults (OWD)

| Object | OWD | How set |
|--------|-----|---------|
| Opportunity | Public Read Only | Must be set manually in org Sharing Settings — not deployable via metadata for standard objects (see Post-Deployment Steps) |
| `Project_Sign_Off__c` | ControlledByParent | Set via `<sharingModel>` in object metadata — deployed automatically |
| `Project_Sprint__c` | ControlledByParent | Set via `<sharingModel>` in object metadata — deployed automatically |
| `Project_Activity__c` | ControlledByParent | Set via `<sharingModel>` in object metadata — deployed automatically |

### 6.2 Permission Sets

| Permission Set | API Name | Description |
|---------------|----------|-------------|
| Project Management Read Write | `ProjectManagement_RW_PS` | Read, Create, Edit on all 5 objects + all custom field permissions |
| Project Management Delete | `ProjectManagement_DELETE_PS` | Read, Delete on all 5 objects |

**Objects covered by both permission sets:** Opportunity, `Project_Sprint__c`, `Project_Activity__c`, `Project_Sign_Off__c`, `Project_Task__c` (existing object).

**Field coverage in `ProjectManagement_RW_PS`:**
- All 13 Opportunity custom fields (rollup fields set editable=false)
- `OpportunityTeamMember.Delivery_Role__c`
- All `Project_Sign_Off__c` editable fields (4)
- All `Project_Sprint__c` editable fields (9) + rollup fields (read=true, editable=false)
- All `Project_Activity__c` fields (9)

**`ProjectManagement_DELETE_PS`** grants only Read + Delete per object — no Create or Edit.

### 6.3 Permission Set Group

| PSG | API Name | Members after this sprint |
|-----|----------|---------------------------|
| Default Admin | `DefaultAdmin_PSG` | `ProjectTask_RW_PS` (existing), `ProjectTask_DELETE_PS` (existing), `ProjectManagement_RW_PS` (new), `ProjectManagement_DELETE_PS` (new) |

---

## 7. Lightning App and Navigation

**App updated:** `The_7_Deadly_Agents`

**Tabs added (appended to existing):**

| Tab | Object |
|-----|--------|
| Standard Opportunity (label: Project Opportunity) | Opportunity |
| Project Sprint | `Project_Sprint__c` |
| Project Activity | `Project_Activity__c` |
| Project Sign Off | `Project_Sign_Off__c` |

**Lightning Record Pages deployed:**

| Page API Name | Object | Key layout features |
|---------------|--------|---------------------|
| `Opportunity_Project_Record_Page` | Opportunity | Header highlights: Project Health, Methodology, Dates; Rollup metrics panel; Related lists: Sprints, Sign Offs, Opportunity Team |
| `Project_Sprint_Record_Page` | `Project_Sprint__c` | Header: Status, Dates, Mandays; Rollup metrics panel; Related list: Activities |
| `Project_Activity_Record_Page` | `Project_Activity__c` | Header: Type, Status, Assigned To, Reviewer; Dates + Mandays panels; Activity Updates; Chatter feed |
| `Project_Sign_Off_Record_Page` | `Project_Sign_Off__c` | Header: Stage, Status, Approval info; Files component; Action button: Upload Sign-Off Document flow |

**Custom Tabs created:** `Project_Sprint__c`, `Project_Activity__c`, `Project_Sign_Off__c`

---

## 8. File Locations

```
force-app/main/default/
├── objects/
│   ├── Opportunity/
│   │   ├── Opportunity.object-meta.xml          (StageName picklist values)
│   │   ├── fields/
│   │   │   ├── Project_Scope__c.field-meta.xml
│   │   │   ├── Project_Description__c.field-meta.xml
│   │   │   ├── Start_Date__c.field-meta.xml
│   │   │   ├── Planned_Go_Live_Date__c.field-meta.xml
│   │   │   ├── Actual_Go_Live_Date__c.field-meta.xml
│   │   │   ├── Planned_Mandays__c.field-meta.xml
│   │   │   ├── Actual_Mandays__c.field-meta.xml
│   │   │   ├── Project_Health__c.field-meta.xml
│   │   │   ├── Delivery_Methodology__c.field-meta.xml
│   │   │   ├── Current_Stage_Sign_Off_Complete__c.field-meta.xml
│   │   │   ├── Total_Sprints__c.field-meta.xml
│   │   │   ├── Total_Planned_Mandays__c.field-meta.xml
│   │   │   └── Total_Actual_Mandays__c.field-meta.xml
│   │   ├── recordTypes/
│   │   │   └── VISEO_Project_Opportunity.recordType-meta.xml
│   │   └── validationRules/
│   │       └── Sign_Off_Required_Before_Stage_Advance.validationRule-meta.xml
│   ├── OpportunityTeamMember/
│   │   └── fields/
│   │       └── Delivery_Role__c.field-meta.xml
│   ├── Project_Sign_Off__c/
│   │   ├── Project_Sign_Off__c.object-meta.xml
│   │   └── fields/
│   │       ├── Opportunity__c.field-meta.xml
│   │       ├── Stage__c.field-meta.xml
│   │       ├── Sign_Off_Status__c.field-meta.xml
│   │       ├── Approved_By__c.field-meta.xml
│   │       └── Approval_Date__c.field-meta.xml
│   ├── Project_Sprint__c/
│   │   ├── Project_Sprint__c.object-meta.xml
│   │   └── fields/
│   │       ├── Opportunity__c.field-meta.xml
│   │       ├── Sprint_Number__c.field-meta.xml
│   │       ├── Sprint_Goal__c.field-meta.xml
│   │       ├── Sprint_Description__c.field-meta.xml
│   │       ├── Sprint_Start_Date__c.field-meta.xml
│   │       ├── Sprint_End_Date__c.field-meta.xml
│   │       ├── Planned_Mandays__c.field-meta.xml
│   │       ├── Actual_Mandays__c.field-meta.xml
│   │       ├── Sprint_Status__c.field-meta.xml
│   │       ├── Total_Activities__c.field-meta.xml
│   │       ├── Total_Completed_Activities__c.field-meta.xml
│   │       ├── Total_Open_Activities__c.field-meta.xml
│   │       ├── Total_Estimated_Mandays__c.field-meta.xml
│   │       └── Total_Actual_Mandays__c.field-meta.xml
│   └── Project_Activity__c/
│       ├── Project_Activity__c.object-meta.xml
│       └── fields/
│           ├── Project_Sprint__c.field-meta.xml
│           ├── Activity_Type__c.field-meta.xml
│           ├── Activity_Status__c.field-meta.xml
│           ├── Assigned_To__c.field-meta.xml
│           ├── Reviewer__c.field-meta.xml
│           ├── Estimated_Mandays__c.field-meta.xml
│           ├── Actual_Mandays__c.field-meta.xml
│           ├── Planned_Completion_Date__c.field-meta.xml
│           ├── Actual_Completion_Date__c.field-meta.xml
│           └── Activity_Updates__c.field-meta.xml
├── flows/
│   ├── Opportunity_Before_Save.flow-meta.xml
│   ├── Opportunity_After_Save.flow-meta.xml
│   └── Project_Sign_Off_Upload_Document.flow-meta.xml
├── pathAssistants/
│   └── VISEO_Project_Opportunity_Path.pathAssistant-meta.xml
├── permissionsets/
│   ├── ProjectManagement_RW_PS.permissionset-meta.xml
│   └── ProjectManagement_DELETE_PS.permissionset-meta.xml
├── permissionsetgroups/
│   └── DefaultAdmin_PSG.permissionsetgroup-meta.xml
├── tabs/
│   ├── Project_Sprint__c.tab-meta.xml
│   ├── Project_Activity__c.tab-meta.xml
│   └── Project_Sign_Off__c.tab-meta.xml
├── flexipages/
│   ├── Opportunity_Project_Record_Page.flexipage-meta.xml
│   ├── Project_Sprint_Record_Page.flexipage-meta.xml
│   ├── Project_Activity_Record_Page.flexipage-meta.xml
│   └── Project_Sign_Off_Record_Page.flexipage-meta.xml
└── applications/
    └── The_7_Deadly_Agents.app-meta.xml
```

---

## 9. Post-Deployment Steps (Manual — Cannot Be Automated)

The following steps must be performed manually by an administrator after deployment:

### 9.1 Opportunity OWD (REQUIRED)

The Opportunity OWD cannot be set to **Public Read Only** via Salesforce metadata for standard objects. After deployment:

1. Go to **Setup > Sharing Settings**.
2. Under **Organization-Wide Defaults**, find **Opportunity**.
3. Set the default internal access to **Public Read Only**.
4. Save.

Without this step, Opportunity records may be overly restricted or overly open depending on the org's current setting.

### 9.2 Lightning Record Page Activation (REQUIRED)

The four Lightning Record Pages are deployed as available pages but are **not automatically set as the org default** (the metadata does not include `<pageAssignments>` blocks). After deployment:

1. Navigate to each record page in **Lightning App Builder**:
   - `Opportunity_Project_Record_Page`
   - `Project_Sprint_Record_Page`
   - `Project_Activity_Record_Page`
   - `Project_Sign_Off_Record_Page`
2. Click **Activation** and set each page as the **Org Default** for its object.
3. Save.

### 9.3 Upload Sign-Off Document Action Button

The Screen Flow `Project_Sign_Off_Upload_Document` is available in the org after deployment. Confirm it appears as a Quick Action / Action button on the `Project_Sign_Off_Record_Page` by opening a sign-off record and checking the action bar.

### 9.4 Assign Permission Sets to Users

Assign the appropriate permission sets to delivery team members:

- `ProjectManagement_RW_PS` — for all users who need to create and edit project records.
- `ProjectManagement_DELETE_PS` — for admins / team leads who need delete access.

Both sets are already members of `DefaultAdmin_PSG` and will apply automatically to users assigned that PSG.

---

## 10. Known Limitations and Code Review Warnings

The code review issued **APPROVED WITH WARNINGS**. The two blocker items were fixed before the PR was raised. Four warnings remain documented here for future sprint awareness.

### Fixed Before PR (Blockers resolved)

| ID | Issue | Resolution |
|----|-------|-----------|
| FAIL-1 | `VISEO_Project_Opportunity.recordType-meta.xml` was missing from version control | File was created and committed |
| FAIL-2 | Empty `<summarizedField></summarizedField>` tag on all 4 COUNT Roll-Up Summary fields caused potential deployment errors | Empty tag was removed from `Total_Sprints__c`, `Total_Activities__c`, `Total_Completed_Activities__c`, `Total_Open_Activities__c` |

### Remaining Warnings (Future Sprint Candidates)

| ID | Severity | Component | Description |
|----|----------|-----------|-------------|
| WARN-1 | Low | Validation Rule | Empty `<errorDisplayField></errorDisplayField>` tag — cosmetic, deploys fine. Recommend removing in a future cleanup. |
| WARN-2 | Medium | `Project_Sign_Off_Upload_Document` | No null/fault path after the two Get Records lookups. If `recordId` is blank or the record is deleted, the flow fails with a generic error rather than a user-friendly message. Recommend adding Decision elements and a fault screen in Sprint 2. |
| WARN-3 | Low | `Opportunity_After_Save` | The "sign-off already exists" decision rule has no connector (execution ends silently). This is correct behavior — no action is needed if the sign-off exists. Documented for clarity only. |
| WARN-4 | Medium | All 4 Lightning Record Pages | No `<pageAssignments>` metadata — pages deploy but are not set as org default automatically. Manual activation required (see Post-Deployment Steps 9.2). |

---

## 11. Design Decisions Reference

| # | Decision | Rationale |
|---|----------|----------|
| 1 | Two permission sets only (RW + DELETE), no RO set | Requirements explicitly specified only these two |
| 2 | `Current_Stage_Sign_Off_Complete__c` checkbox as gating field | Enables declarative Validation Rule and Flow logic without Apex |
| 3 | Before-Save flow resets checkbox; After-Save flow creates sign-off record | Before-Save can write to `$Record` (no DML); After-Save handles DML — avoids recursive DML issues |
| 4 | Sign-off document stored as Salesforce File (ContentDocument) | Standard File Upload component in Screen Flow — no custom file field needed |
| 5 | `Project_Task__c` included in permission sets without creating a new object | References the existing `Project_Task__c` object from a prior sprint |
| 6 | Auto Number names for `Project_Sign_Off__c` (PSO-) and `Project_Activity__c` (ACT-) | Better UX — avoids manual naming; provides a unique human-readable reference |
| 7 | `Total_Open_Activities__c` uses two NOT EQUAL TO filter criteria | Roll-Up Summary filters do not support OR logic — two AND-combined NOT EQUAL criteria produce the correct count of activities that are neither Completed nor Cancelled |

---

*Document created by salesforce-documentation agent. For design rationale and full specifications, refer to `agent-output/design-requirements.md`. For the complete component list, refer to `agent-output/components-created.md`. For the full code review report, refer to `agent-output/review-findings.md`.*
