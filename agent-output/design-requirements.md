# Design Requirements — Sign-Off Refactor, LRP Dynamic Forms & Path Components

**Date:** 2026-06-21
**API Version:** 65.0
**Package Dir:** `force-app/main/default`

---

## Current-State Findings (from metadata read)

| Item | Current State |
|------|---------------|
| Sign-off stages | Discovery, Requirement Gathering, Requirement Documentation, User Story Finalization (first 4 of OpportunityStage) |
| Shared checkbox | `Current_Stage_Sign_Off_Complete__c` (single checkbox, reset in Before Save) |
| Before Save flow | `Opportunity_Before_Save` — resets `Current_Stage_Sign_Off_Complete__c` to false on entering a sign-off stage |
| After Save flow | `Opportunity_After_Save` — creates a `Project_Sign_Off__c` when StageName ISCHANGED to a sign-off stage; does NOT reliably fire on initial create |
| Validation rule | `Sign_Off_Required_Before_Stage_Advance` — blocks stage advance when leaving a sign-off stage and `Current_Stage_Sign_Off_Complete__c` is false |
| Upload flow | `Project_Sign_Off_Upload_Document` — screen flow; on approval sets `Current_Stage_Sign_Off_Complete__c = true` and Sign Off Status = Approved |
| Opp LRP | `Opportunity_Project_Record_Page` — uses `force:detailPanel` (renders page layout, NOT Dynamic Forms) |
| Mandatory/read-only source | Page layout `Opportunity-VISEO Project Opportunity Layout`: Required = Name, AccountId, CloseDate, StageName; Readonly = Total_Planned_Mandays__c, Total_Actual_Mandays__c, Current_Stage_Sign_Off_Complete__c |
| No field-level `required=true` | Confirmed — no Opportunity custom field has field-level required metadata |
| Sprint LRP | `Project_Sprint_Record_Page` — Dynamic Forms, header has highlightsPanel only; status field = `Sprint_Status__c` |
| Activity LRP | `Project_Activity_Record_Page` — Dynamic Forms, header has highlightsPanel only; status field = `Activity_Status__c` |

---

## WHAT USER REQUESTED

1. Fix `Opportunity_Before_Save`: stop resetting a shared checkbox. Replace the single shared sign-off checkbox with one dedicated checkbox per sign-off stage so they no longer conflict. Before Save no longer resets any flag.
2. `Opportunity_After_Save`: auto-create a `Project_Sign_Off__c` when an Opportunity is created OR when StageName is updated to a sign-off stage.
3. Move field-level mandatory & read-only to the Lightning Record Page (Dynamic Forms) — do NOT change field-level required/read-only metadata.
4. Add Path component to Project Sprint and Project Activity record pages, reflecting their status field.

---

## ADMIN WORK (salesforce-admin)

### A1 — New dedicated sign-off checkbox fields on Opportunity (one per sign-off stage)
Create four Checkbox fields, default `false`, `type=Checkbox`, API 65.0:
- `Sign_Off_Discovery_Complete__c` — Label "Discovery Sign Off Complete"
- `Sign_Off_Req_Gathering_Complete__c` — Label "Requirement Gathering Sign Off Complete"
- `Sign_Off_Req_Documentation_Complete__c` — Label "Requirement Documentation Sign Off Complete"
- `Sign_Off_User_Story_Complete__c` — Label "User Story Finalization Sign Off Complete"

Do NOT delete `Current_Stage_Sign_Off_Complete__c` in this branch (still referenced by upload flow + permission sets + layout until dev rewires flows). Mark it for later cleanup — see Open Question Q1.

### A2 — Permission sets (mandatory — object touched with new fields)
Update all three Opportunity permission sets to grant field permissions for the four new checkbox fields:
- `Opportunity_RO_PS` — readable
- `Opportunity_RW_PS` — readable + editable
- `Opportunity_DELETE_PS` — match existing pattern (if it exists; if not, do not create solely for this)
(Reuse existing PS files; do not create new sets.)

### A3 — Opportunity LRP: ALREADY DONE IN ORG (verified by retrieve 2026-06-21)
Retrieved `Opportunity_Project_Record_Page` from org "ARIEF VISEO DEV ORG". The org version is ALREADY migrated to Dynamic Forms and ALREADY has page-level mandatory/read-only set. The local file was stale and has now been refreshed. NO new admin work required for req #3.
Org page already contains:
- Dynamic Forms: 4 `flexipage:fieldSection` (Project Information, Dates, Mandays, Project Status) — no `force:detailPanel`
- `required` uiBehavior: Name, AccountId, CloseDate, StageName
- `readonly` uiBehavior: Total_Planned_Mandays__c, Total_Actual_Mandays__c, Current_Stage_Sign_Off_Complete__c
- A Path component (`runtime_sales_pathassistant:pathAssistant`) already in the `subheader` region
No field-level metadata changes needed. ACTION: commit the refreshed flexipage file to the branch so it is no longer stale; no further edits.

### A4 — Path component on Project Sprint record page (still needed — verified absent in org)
Add a `subheader` region to `Project_Sprint_Record_Page` containing the Path component (componentName `runtime_sales_pathassistant:pathAssistant`, properties `hideUpdateButton=false`, `variant=linear`). Pattern: copy the exact `subheader` region from the org's `Opportunity_Project_Record_Page` (template is `recordHomeWithSubheaderTemplateDesktop` on all three pages, so Path goes in `subheader`, NOT `header`). Path drives off `Sprint_Status__c`.
(Requires a `PathAssistant` setting for `Project_Sprint__c.Sprint_Status__c` — see Q2.)

### A5 — Path component on Project Activity record page (still needed — verified absent in org)
Add a `subheader` region to `Project_Activity_Record_Page` containing the same Path component. Path drives off `Activity_Status__c`.
(Requires a `PathAssistant` setting for `Project_Activity__c.Activity_Status__c` — see Q2.)

---

## DEV WORK (salesforce-developer)

> Note: All items below are FLOW (declarative) work, not Apex/LWC. Flows are built by the developer agent per the workflow table. No handler/trigger pattern applies.

### D1 — `Opportunity_Before_Save` — ALREADY OBSOLETE IN ORG (verified by retrieve 2026-06-21)
The org version of this flow is already `status=Obsolete` (deactivated), so it is no longer resetting any flag — req #1's "Before Save no longer resets" is already satisfied at runtime. Optional cleanup: remove the now-dead `Set_Sign_Off_Complete_False` assignment from the flow definition for hygiene. No reactivation. Lowest-risk option: leave Obsolete as-is and just commit the retrieved file.

### D2 — Rewrite `Opportunity_After_Save`
Trigger on Create AND Update. Fire when:
- record is created with StageName in a sign-off stage, OR
- StageName ISCHANGED to a sign-off stage.
Adjust `filterFormula` so `ISCHANGED` does not suppress the create case (use `ISNEW() || (ISCHANGED(StageName) && ...)` pattern). Keep the existing "Sign Off Exists?" guard (lookup by Opportunity + Stage; create with Status=Pending only if none found).

### D3 — Rewire `Project_Sign_Off_Upload_Document` to dedicated checkboxes
On approval, instead of setting the shared `Current_Stage_Sign_Off_Complete__c`, set the dedicated checkbox matching `varSignOff.Stage__c`:
- Discovery → `Sign_Off_Discovery_Complete__c`
- Requirement Gathering → `Sign_Off_Req_Gathering_Complete__c`
- Requirement Documentation → `Sign_Off_Req_Documentation_Complete__c`
- User Story Finalization → `Sign_Off_User_Story_Complete__c`
Use a Decision on Stage to pick the field to set true.

### D4 — Update validation rule `Sign_Off_Required_Before_Stage_Advance`
Change the errorConditionFormula so the gate checks the dedicated checkbox for the stage being LEFT (PRIORVALUE(StageName)) instead of the shared checkbox:
- leaving Discovery → require `Sign_Off_Discovery_Complete__c`
- leaving Requirement Gathering → require `Sign_Off_Req_Gathering_Complete__c`
- leaving Requirement Documentation → require `Sign_Off_Req_Documentation_Complete__c`
- leaving User Story Finalization → require `Sign_Off_User_Story_Complete__c`
(Validation rule is metadata on the object — recommend assigning to admin since it is declarative. Listed here because it is tightly coupled to the checkbox refactor logic.)

---

## ROUTING DECISION

- DECLARATIVE_ONLY: **NO** (flows require the developer agent per workflow; but NO Apex/Trigger/LWC). If orchestrator treats flows as admin-buildable, this becomes YES — confirm via Q4.

## EXECUTION ORDER

1. A1 (new checkbox fields) — must exist before flows/VR/PS reference them
2. A2 (permission sets), A4/A5 (Path settings + components on Sprint/Activity) — after A1
3. D2, D3, D4 (After Save fix + Upload flow rewire + VR rewire) — after A1
4. A3 — NO-OP (already done in org; just commit refreshed file). D1 — Before Save already Obsolete in org (commit refreshed file; optional dead-assignment cleanup).
5. Code review → Documentation

---

## PROMPT FOR salesforce-admin

"""
Branch: read agent-output/current-branch.md. Commit only, do not deploy. API 65.0.

1. Create four Opportunity Checkbox fields (default false): Sign_Off_Discovery_Complete__c (label "Discovery Sign Off Complete"), Sign_Off_Req_Gathering_Complete__c (label "Requirement Gathering Sign Off Complete"), Sign_Off_Req_Documentation_Complete__c (label "Requirement Documentation Sign Off Complete"), Sign_Off_User_Story_Complete__c (label "User Story Finalization Sign Off Complete"). Do NOT delete Current_Stage_Sign_Off_Complete__c.
2. Update Opportunity_RO_PS (read), Opportunity_RW_PS (read+edit), and Opportunity_DELETE_PS if it exists, granting field perms for the four new fields. Reuse existing PS files.
3. Opportunity_Project_Record_Page — NO ACTION NEEDED. Already migrated to Dynamic Forms in the org with page-level required (Name, AccountId, CloseDate, StageName) and readonly (Total_Planned_Mandays__c, Total_Actual_Mandays__c, Current_Stage_Sign_Off_Complete__c). The refreshed file is already in the branch — just commit it.
4. Add the Path component (componentName runtime_sales_pathassistant:pathAssistant, properties hideUpdateButton=false, variant=linear) to a NEW subheader region (NOT header) on Project_Sprint_Record_Page (drives off Sprint_Status__c) and Project_Activity_Record_Page (drives off Activity_Status__c). Both use template recordHomeWithSubheaderTemplateDesktop — copy the exact subheader region pattern from the org's Opportunity_Project_Record_Page. Create the PathAssistant settings for Project_Sprint__c.Sprint_Status__c and Project_Activity__c.Activity_Status__c if they do not already exist (use existing picklist order, no guidance text).
5. Update validation rule Sign_Off_Required_Before_Stage_Advance to require the dedicated checkbox of the stage being left (PRIORVALUE(StageName)): Discovery→Sign_Off_Discovery_Complete__c, Requirement Gathering→Sign_Off_Req_Gathering_Complete__c, Requirement Documentation→Sign_Off_Req_Documentation_Complete__c, User Story Finalization→Sign_Off_User_Story_Complete__c.
"""

## PROMPT FOR salesforce-developer

"""
Branch: read agent-output/current-branch.md. Commit only, do not deploy. API 65.0. Flow work only (no Apex/LWC). Depends on the four new Opportunity checkbox fields being created first.

1. Opportunity_Before_Save: ALREADY Obsolete in org — no reactivation. Optional hygiene only: remove the dead Set_Sign_Off_Complete_False assignment from the obsolete flow definition. Otherwise just commit the retrieved file.
2. Opportunity_After_Save: trigger Create AND Update; fire when a record is created in a sign-off stage OR StageName ISCHANGED to a sign-off stage (Discovery, Requirement Gathering, Requirement Documentation, User Story Finalization). Fix filterFormula so the create case is not suppressed (ISNEW() OR ISCHANGED pattern). Keep the existing "Sign Off Exists?" guard; create Project_Sign_Off__c with Sign_Off_Status__c=Pending and Stage__c=StageName only if none exists for that Opportunity+Stage.
3. Project_Sign_Off_Upload_Document: on approval, set the dedicated Opportunity checkbox matching varSignOff.Stage__c (Discovery→Sign_Off_Discovery_Complete__c, Requirement Gathering→Sign_Off_Req_Gathering_Complete__c, Requirement Documentation→Sign_Off_Req_Documentation_Complete__c, User Story Finalization→Sign_Off_User_Story_Complete__c) via a Decision on Stage, instead of Current_Stage_Sign_Off_Complete__c.
"""

---

## RESOLVED DECISIONS (defaults applied in auto mode — flag for user if any differ)

- **Q1 — Old shared checkbox:** KEEP `Current_Stage_Sign_Off_Complete__c` this sprint (lowest risk). Leave it in permission sets, page layout, and LRP readonly placement. Decommission in a later follow-up once the dedicated-checkbox flow is proven in the org.
- **Q2 — Path settings:** Admin CREATES `PathAssistant` settings for `Project_Sprint__c.Sprint_Status__c` and `Project_Activity__c.Activity_Status__c` using the existing status picklist order, no per-step guidance text.
- **Q3 — Before Save flow:** N/A — `Opportunity_Before_Save` is ALREADY `Obsolete` in the org (verified by retrieve). No action beyond optional dead-assignment cleanup.
- **Q4 — Flow ownership:** Flow edits route to **salesforce-developer** per the workflow table. DECLARATIVE_ONLY: NO (no Apex/Trigger/LWC, but flows go through the developer step).

---

NEXT_AGENT: salesforce-admin

**Branch:** `feature/2026-06-21-signoff-refactor-lrp-path` (created from freshly pulled main)
