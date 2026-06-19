# Design Requirements — Project Delivery Management (Sprint 1)

**Branch:** `feature/2026-06-19-project-delivery-management-sprint1`
**Date:** 2026-06-19
**API Version:** 65.0
**Package Dir:** `force-app/main/default`
**Route:** Admin → Code Review → Documentation → DevOps
**Declarative Only:** YES (no Apex/Trigger/LWC)

---

## 1. Existing Org Assets (Do Not Re-create)

| Asset | API Name | Notes |
|-------|----------|-------|
| App | `The_7_Deadly_Agents` | Add tabs to this app |
| Object | `Project_Task__c` | Existing — referenced in permission sets |
| PSG | `DefaultAdmin_PSG` | Existing — add new PSs to it |
| PSs in PSG | `ProjectTask_RW_PS`, `ProjectTask_DELETE_PS` | Existing members — keep them |

---

## 2. Object: Opportunity (Standard)

**Business Label:** Project Opportunity

### 2.1 Record Type

| Property | Value |
|----------|-------|
| API Name | `VISEO_Project_Opportunity` |
| Label | VISEO Project Opportunity |
| Active | true |

### 2.2 Opportunity Path

- **Path API Name:** `VISEO_Project_Opportunity_Path`
- **Object:** Opportunity | **Field:** StageName
- **Stages (in order):**
  1. Discovery
  2. Requirement Gathering
  3. Requirement Documentation
  4. User Story Finalization
  5. In Development
  6. QA
  7. UAT
  8. Live
  9. AMS

> Admin must add any missing stage values to the StageName global picklist / field before deploying the Path.

### 2.3 Custom Fields on Opportunity

| Label | API Name | Type | Properties |
|-------|----------|------|------------|
| Project Scope | `Project_Scope__c` | LongTextArea | Length 32768, VisibleLines 6 |
| Project Description | `Project_Description__c` | LongTextArea | Length 32768, VisibleLines 6 |
| Start Date | `Start_Date__c` | Date | — |
| Planned Go-Live Date | `Planned_Go_Live_Date__c` | Date | — |
| Actual Go-Live Date | `Actual_Go_Live_Date__c` | Date | — |
| Planned Mandays | `Planned_Mandays__c` | Number | Precision 8, Scale 2 |
| Actual Mandays | `Actual_Mandays__c` | Number | Precision 8, Scale 2 |
| Project Health | `Project_Health__c` | Picklist | Values: On Track; At Risk; Off Track |
| Delivery Methodology | `Delivery_Methodology__c` | Picklist | Values: Agile; Waterfall; Hybrid |
| Current Stage Sign Off Complete | `Current_Stage_Sign_Off_Complete__c` | Checkbox | Default: false — used by flows and validation rule |

### 2.4 Roll-Up Summary Fields on Opportunity (from Project_Sprint__c)

| Label | API Name | Operation | Child Object | Child Field | Criteria |
|-------|----------|-----------|--------------|-------------|----------|
| Total Sprints | `Total_Sprints__c` | COUNT | `Project_Sprint__c` | — | All records |
| Total Planned Mandays | `Total_Planned_Mandays__c` | SUM | `Project_Sprint__c` | `Planned_Mandays__c` | All records |
| Total Actual Mandays | `Total_Actual_Mandays__c` | SUM | `Project_Sprint__c` | `Actual_Mandays__c` | All records |

---

## 3. OpportunityTeamMember Custom Field

| Label | API Name | Type | Properties |
|-------|----------|------|------------|
| Delivery Role | `Delivery_Role__c` | Picklist | Values: Project Manager; Solution Architect; Technical Architect; Business Analyst; Functional Consultant; Technical Consultant; Developer; QA Engineer; Scrum Master; AMS Consultant; Support Consultant; Other |

---

## 4. Object: Project Sign Off (Custom)

| Property | Value |
|----------|-------|
| API Name | `Project_Sign_Off__c` |
| Label | Project Sign Off |
| Plural Label | Project Sign Offs |
| Name Field | Auto Number — format `PSO-{0000}` |
| Sharing Model | ControlledByParent |
| Chatter | false |
| Reports | true |

### 4.1 Fields

| Label | API Name | Type | Properties |
|-------|----------|------|------------|
| Opportunity | `Opportunity__c` | Master-Detail (Opportunity) | Required |
| Stage | `Stage__c` | Picklist | Values: Discovery; Requirement Gathering; Requirement Documentation; User Story Finalization |
| Sign Off Status | `Sign_Off_Status__c` | Picklist | Values: Pending; Approved; Rejected — Default: Pending |
| Approved By | `Approved_By__c` | Lookup (User) | — |
| Approval Date | `Approval_Date__c` | Date | — |

> File upload is handled via Salesforce Files (ContentDocument). The Screen Flow uses a standard File Upload component — no custom file field needed.

---

## 5. Object: Project Sprint (Custom)

| Property | Value |
|----------|-------|
| API Name | `Project_Sprint__c` |
| Label | Project Sprint |
| Plural Label | Project Sprints |
| Name Field | Text — label `Sprint Name` |
| Sharing Model | ControlledByParent |
| Reports | true |

### 5.1 Fields

| Label | API Name | Type | Properties |
|-------|----------|------|------------|
| Opportunity | `Opportunity__c` | Master-Detail (Opportunity) | Required |
| Sprint Number | `Sprint_Number__c` | Number | Precision 8, Scale 0 |
| Sprint Goal | `Sprint_Goal__c` | Text | Length 255 |
| Sprint Description | `Sprint_Description__c` | LongTextArea | Length 32768, VisibleLines 4 |
| Sprint Start Date | `Sprint_Start_Date__c` | Date | — |
| Sprint End Date | `Sprint_End_Date__c` | Date | — |
| Planned Mandays | `Planned_Mandays__c` | Number | Precision 8, Scale 2 |
| Actual Mandays | `Actual_Mandays__c` | Number | Precision 8, Scale 2 |
| Sprint Status | `Sprint_Status__c` | Picklist | Values: Planning; In Progress; Complete; Cancelled — Default: Planning |

### 5.2 Roll-Up Summary Fields on Project Sprint (from Project_Activity__c)

| Label | API Name | Operation | Child Field | Criteria |
|-------|----------|-----------|-------------|----------|
| Total Activities | `Total_Activities__c` | COUNT | — | All records |
| Total Completed Activities | `Total_Completed_Activities__c` | COUNT | — | `Activity_Status__c` equals `Completed` |
| Total Open Activities | `Total_Open_Activities__c` | COUNT | — | `Activity_Status__c` not equal to `Completed` AND `Activity_Status__c` not equal to `Cancelled` |
| Total Estimated Mandays | `Total_Estimated_Mandays__c` | SUM | `Estimated_Mandays__c` | All records |
| Total Actual Mandays | `Total_Actual_Mandays__c` | SUM | `Actual_Mandays__c` | All records |

---

## 6. Object: Project Activity (Custom)

| Property | Value |
|----------|-------|
| API Name | `Project_Activity__c` |
| Label | Project Activity |
| Plural Label | Project Activities |
| Name Field | Auto Number — format `ACT-{00000}` |
| Sharing Model | ControlledByParent |
| Chatter (Feed Tracking) | true |
| Reports | true |

### 6.1 Fields

| Label | API Name | Type | Properties |
|-------|----------|------|------------|
| Project Sprint | `Project_Sprint__c` | Master-Detail (Project_Sprint__c) | Required |
| Activity Type | `Activity_Type__c` | Picklist | Values: Development; QA; BA; Design; DevOps; Other |
| Activity Status | `Activity_Status__c` | Picklist | Values: Not Started; In Progress; In Review; Completed; Blocked; Cancelled — Default: Not Started |
| Assigned To | `Assigned_To__c` | Lookup (User) | — |
| Reviewer | `Reviewer__c` | Lookup (User) | — |
| Estimated Mandays | `Estimated_Mandays__c` | Number | Precision 8, Scale 2 |
| Actual Mandays | `Actual_Mandays__c` | Number | Precision 8, Scale 2 |
| Planned Completion Date | `Planned_Completion_Date__c` | Date | — |
| Actual Completion Date | `Actual_Completion_Date__c` | Date | — |
| Activity Updates | `Activity_Updates__c` | LongTextArea | Length 32768, VisibleLines 4 |

---

## 7. Flows

### 7.1 Before-Save Flow: Opportunity Before Save (Sign Off Reset)

| Property | Value |
|----------|-------|
| API Name | `Opportunity_Before_Save` |
| Label | Opportunity Before Save |
| Object | Opportunity |
| Trigger | Before Save (Create and Edit) |
| Entry Criteria | `StageName` IS CHANGED AND new value is one of: Discovery, Requirement Gathering, Requirement Documentation, User Story Finalization |

**Logic:** Assignment element — set `Current_Stage_Sign_Off_Complete__c` = false on `{!$Record}`

### 7.2 After-Save Flow: Opportunity After Save (Sign Off Auto-Create)

| Property | Value |
|----------|-------|
| API Name | `Opportunity_After_Save` |
| Label | Opportunity After Save |
| Object | Opportunity |
| Trigger | After Save (Create and Edit) |
| Entry Criteria | `StageName` IS CHANGED AND new value is one of: Discovery, Requirement Gathering, Requirement Documentation, User Story Finalization |

**Logic:**
1. Get Records: Query `Project_Sign_Off__c` where `Opportunity__c = {$Record.Id}` AND `Stage__c = {$Record.StageName}` — limit 1
2. Decision: if no records found → proceed to Create
3. Create Record: `Project_Sign_Off__c` — `Opportunity__c = {$Record.Id}`, `Stage__c = {$Record.StageName}`, `Sign_Off_Status__c = Pending`

### 7.3 Screen Flow: Upload Sign-Off Document

| Property | Value |
|----------|-------|
| API Name | `Project_Sign_Off_Upload_Document` |
| Label | Upload Sign-Off Document |
| Type | Screen Flow |

**Input Variable:** `recordId` (Text, Input) — the Project Sign Off record ID

**Steps:**
1. Get Records: Get `Project_Sign_Off__c` by `{!recordId}` → `varSignOff`
2. Get Records: Get parent Opportunity via `varSignOff.Opportunity__c` → `varOpportunity`
3. Screen 1 — Upload Document: File Upload component (related record = `{!recordId}`), required confirm checkbox
4. Screen 2 — Confirm Approval: required confirm checkbox
5. Update Records: Sign Off — set `Sign_Off_Status__c = Approved`, `Approved_By__c = {!$User.Id}`, `Approval_Date__c = {!$Flow.CurrentDate}`
6. Update Records: Opportunity — set `Current_Stage_Sign_Off_Complete__c = true`

**Placement:** Add as Action button on Project Sign Off Lightning Record Page.

---

## 8. Validation Rule on Opportunity

| Property | Value |
|----------|-------|
| Object | Opportunity |
| API Name | `Sign_Off_Required_Before_Stage_Advance` |
| Active | true |
| Error Message | Please complete and approve the sign-off document for the current stage before advancing. |

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

---

## 9. Permission Sets

### 9.1 ProjectManagement_RW_PS

| API Name | `ProjectManagement_RW_PS` |
|----------|---------------------------|
| Label | Project Management Read Write |

Object Permissions: Read + Create + Edit on Opportunity, Project_Sprint__c, Project_Activity__c, Project_Sign_Off__c, Project_Task__c.
Field Permissions: Read + Edit on all custom fields listed in sections 2.3, 3, 4.1, 5.1, 6.1.

### 9.2 ProjectManagement_DELETE_PS

| API Name | `ProjectManagement_DELETE_PS` |
|----------|-------------------------------|
| Label | Project Management Delete |

Object Permissions: Read + Delete on Opportunity, Project_Sprint__c, Project_Activity__c, Project_Sign_Off__c, Project_Task__c.

### 9.3 Permission Set Group: DefaultAdmin_PSG

Add to existing `DefaultAdmin_PSG`: `ProjectManagement_RW_PS` + `ProjectManagement_DELETE_PS`.
Keep existing members: `ProjectTask_RW_PS`, `ProjectTask_DELETE_PS`.

---

## 10. Lightning App: The 7 Deadly Agents

Append to existing `The_7_Deadly_Agents` app tabs:
- Standard Opportunity tab
- `Project_Sprint__c` tab
- `Project_Activity__c` tab
- `Project_Sign_Off__c` tab

Create custom tabs for `Project_Sprint__c`, `Project_Activity__c`, `Project_Sign_Off__c` if they do not already exist.

---

## 11. Lightning Record Pages

| Object | Page Name | Key Sections |
|--------|-----------|-------------|
| Opportunity | `Opportunity_Project_Record_Page` | Header: Project Health, Methodology, Dates; Rollups panel; Related: Sprints, Sign Offs, Opportunity Team |
| `Project_Sprint__c` | `Project_Sprint_Record_Page` | Header: Status, Dates, Mandays; Rollups panel; Related: Activities |
| `Project_Activity__c` | `Project_Activity_Record_Page` | Header: Type, Status, Assignee, Reviewer; Dates + Mandays; Activity Updates; Chatter |
| `Project_Sign_Off__c` | `Project_Sign_Off_Record_Page` | Header: Stage, Status, Approval info; Files component; Action: Upload Sign-Off Document flow |

Assign all pages as org default for their respective object.

---

## 12. OWD / Sharing Settings

| Object | OWD |
|--------|-----|
| Opportunity | Public Read Only (set in org Sharing Settings — not deployable via metadata) |
| `Project_Sprint__c` | ControlledByParent (set via `sharingModel` in object metadata) |
| `Project_Activity__c` | ControlledByParent |
| `Project_Sign_Off__c` | ControlledByParent |

---

## 13. Execution Order for Admin Agent

1. Opportunity Stage picklist values (add all 9 stages)
2. Opportunity custom fields (section 2.3 — no rollups yet)
3. Opportunity Record Type: `VISEO_Project_Opportunity`
4. Opportunity Path: `VISEO_Project_Opportunity_Path`
5. OpportunityTeamMember field: `Delivery_Role__c`
6. `Project_Sign_Off__c` object + fields
7. `Project_Sprint__c` object + fields (no rollups yet)
8. `Project_Activity__c` object + fields
9. Roll-Up Summary fields on `Project_Sprint__c`
10. Roll-Up Summary fields on Opportunity
11. Flow: `Opportunity_Before_Save`
12. Flow: `Opportunity_After_Save`
13. Flow: `Project_Sign_Off_Upload_Document`
14. Validation Rule: `Sign_Off_Required_Before_Stage_Advance`
15. Permission Set: `ProjectManagement_RW_PS`
16. Permission Set: `ProjectManagement_DELETE_PS`
17. Permission Set Group: `DefaultAdmin_PSG` (add new PSs, keep existing)
18. Lightning Record Pages (all 4)
19. Custom Tabs for new objects (if missing)
20. App update: `The_7_Deadly_Agents` (add 4 tabs)

---

## 14. Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| 1 | Only 2 permission sets (RW + DELETE), no RO | Requirement explicitly specifies only these two |
| 2 | `Current_Stage_Sign_Off_Complete__c` checkbox on Opportunity | Enables validation rule without Apex; managed by flows |
| 3 | Split Before-Save + After-Save flows | Before-Save resets checkbox safely; After-Save creates sign-off — avoids recursive DML |
| 4 | Sign-off document via Salesforce Files | Standard File Upload component in Screen Flow; no custom field needed |
| 5 | `Project Task` in permission sets = existing `Project_Task__c` | No new task object |
| 6 | Auto Number name on Project Sign Off and Project Activity | Better UX |
| 7 | Total_Open_Activities uses two NOT EQUAL TO criteria | Roll-Up Summary supports this on picklist fields |

---

NEXT_AGENT: salesforce-admin
