# Design Requirements — Sign-Off Field Name Fix

**Date:** 2026-06-21
**Branch:** `fix/2026-06-21-signoff-field-rename`
**API Version:** 65.0
**Parent PR:** #9 (merged — never deployed, blocked by field name + VR bugs)

---

## Context

PR #9 introduced 4 per-stage sign-off checkbox fields on Opportunity. Three of the four API names exceed Salesforce's 40-char limit and could not be deployed. The validation rule also still references the field being destructively removed (`Current_Stage_Sign_Off_Complete__c`). This fix branch resolves all blockers.

---

## Already Done (staged, not yet committed)

| Action | File |
|--------|------|
| Renamed `Requirement_Documentation_Sign_Off_Complete__c` → `Req_Documentation_Sign_Off_Complete__c` | `objects/Opportunity/fields/` |
| Renamed `Requirement_Gathering_Sign_Off_Complete__c` → `Req_Gathering_Sign_Off_Complete__c` | `objects/Opportunity/fields/` |
| Renamed `User_Story_Finalization_Sign_Off_Complete__c` → `User_Story_Sign_Off_Complete__c` | `objects/Opportunity/fields/` |
| Deleted `DataCloudGeoLocation.cleanDataService-meta.xml` | `cleanDataServices/` |
| `Discovery_Sign_Off_Complete__c` (30 chars) | unchanged — keep as-is |

---

## ADMIN WORK (salesforce-admin)

### A2 — Validation rule `Sign_Off_Required_Before_Stage_Advance`
File: `force-app/main/default/objects/Opportunity/validationRules/Sign_Off_Required_Before_Stage_Advance.validationRule-meta.xml`

Replace the current `errorConditionFormula` (which contains `NOT(Current_Stage_Sign_Off_Complete__c)`) with a per-stage gate using `PRIORVALUE(StageName)`:

```
AND(
  OR(
    PRIORVALUE(StageName) = "Discovery",
    PRIORVALUE(StageName) = "Requirement Gathering",
    PRIORVALUE(StageName) = "Requirement Documentation",
    PRIORVALUE(StageName) = "User Story Finalization"
  ),
  ISCHANGED(StageName),
  CASE(
    PRIORVALUE(StageName),
    "Discovery", NOT(Discovery_Sign_Off_Complete__c),
    "Requirement Gathering", NOT(Req_Gathering_Sign_Off_Complete__c),
    "Requirement Documentation", NOT(Req_Documentation_Sign_Off_Complete__c),
    "User Story Finalization", NOT(User_Story_Sign_Off_Complete__c),
    FALSE
  )
)
```

### A3 — Permission sets
Files: `force-app/main/default/permissionsets/Opportunity_RO_PS.permissionset-meta.xml`, `Opportunity_RW_PS.permissionset-meta.xml`, `Opportunity_DELETE_PS.permissionset-meta.xml`

- Remove `Current_Stage_Sign_Off_Complete__c` field permission entries (field is being deleted)
- Add field permissions for all 4 per-stage checkboxes:
  - `Discovery_Sign_Off_Complete__c`
  - `Req_Gathering_Sign_Off_Complete__c`
  - `Req_Documentation_Sign_Off_Complete__c`
  - `User_Story_Sign_Off_Complete__c`
- RO PS: readable=true, editable=false
- RW PS: readable=true, editable=true
- DELETE PS: readable=true, editable=true

### A4 — Clean remaining `Current_Stage_Sign_Off_Complete__c` references

1. **`Opportunity_Project_Record_Page.flexipage-meta.xml`** — remove the `readonly` uiBehavior entry for `Current_Stage_Sign_Off_Complete__c`
2. **`Opportunity-VISEO Project Opportunity Layout.layout-meta.xml`** — remove the field from the layout sections
3. **`objectTranslations/Current_Stage_Sign_Off_Complete__c.fieldTranslation-meta.xml`** — delete this file entirely

---

## DEV WORK (salesforce-developer)

### D1 — `Project_Sign_Off_Upload_Document` flow (Active)
File: `force-app/main/default/flows/Project_Sign_Off_Upload_Document.flow-meta.xml`

Replace the single `Current_Stage_Sign_Off_Complete__c = true` assignment with a Decision element on `{!varSignOff.Stage__c}` that routes to 4 separate assignments:
- "Discovery" → set `Discovery_Sign_Off_Complete__c = true` on the Opportunity record
- "Requirement Gathering" → set `Req_Gathering_Sign_Off_Complete__c = true`
- "Requirement Documentation" → set `Req_Documentation_Sign_Off_Complete__c = true`
- "User Story Finalization" → set `User_Story_Sign_Off_Complete__c = true`

### D2 — `Opportunity_Before_Save` flow (Obsolete)
File: `force-app/main/default/flows/Opportunity_Before_Save.flow-meta.xml`

Remove the 2 dead `Current_Stage_Sign_Off_Complete__c` references from the Obsolete flow definition. Do NOT reactivate this flow.

---

## EXCLUDED

- All 44 profile files — do NOT modify any profile metadata
- `DataCloudGeoLocation.cleanDataService-meta.xml` — already deleted from branch, keep excluded

---

## EXECUTION ORDER

1. A2, A3, A4 (admin) — can run in parallel, all depend on renamed fields already being present
2. D1, D2 (developer) — after admin commits
3. Code review → Documentation → PR → DevOps deploy

NEXT_AGENT: salesforce-admin
