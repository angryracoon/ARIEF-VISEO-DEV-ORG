# Fix — Sign-Off Field Rename and Deployment Blockers
**Branch:** `fix/2026-06-21-signoff-field-rename`
**Date:** 2026-06-21
**API Version:** 65.0
**Parent PR:** #9 (merged — deployment blocked)

---

## Why This Fix Exists

PR #9 (Sprint 3) was merged to `main` but could not be deployed to the org. Two categories of blockers prevented deployment:

1. **Field API names exceeded the 40-character limit.** Three of the four per-stage sign-off checkbox fields introduced in Sprint 3 had API names longer than 40 characters. Salesforce enforces a hard 40-character limit on field API names (`CustomField`). The deploy failed at metadata validation before any component reached the org.

2. **Validation rule and flow still referenced the deleted field.** `Current_Stage_Sign_Off_Complete__c` was staged for destructive removal, but the `Sign_Off_Required_Before_Stage_Advance` validation rule formula and the `Project_Sign_Off_Upload_Document` flow still referenced it. Deploying the destructive package while these references were live would have caused a dependent component error.

This fix branch resolves all three blockers so the components can be cleanly deployed and `Current_Stage_Sign_Off_Complete__c` can be safely removed from the org.

---

## Field API Name Changes (Rename)

Three fields were renamed to bring all API names within the 40-character limit. `Discovery_Sign_Off_Complete__c` (30 chars) was already within limit and is unchanged.

| Old API Name (PR #9 — over limit) | New API Name (this fix) | Char count |
|----------------------------------|-------------------------|------------|
| `Requirement_Gathering_Sign_Off_Complete__c` (44) | `Req_Gathering_Sign_Off_Complete__c` | 36 |
| `Requirement_Documentation_Sign_Off_Complete__c` (48) | `Req_Documentation_Sign_Off_Complete__c` | 40 |
| `User_Story_Finalization_Sign_Off_Complete__c` (46) | `User_Story_Sign_Off_Complete__c` | 32 |

All four renamed field files are located at:
```
force-app/main/default/objects/Opportunity/fields/
```

---

## What Was Cleaned Up

### Validation Rule — Formula Rewrite
**File:** `force-app/main/default/objects/Opportunity/validationRules/Sign_Off_Required_Before_Stage_Advance.validationRule-meta.xml`

The formula previously used `NOT(Current_Stage_Sign_Off_Complete__c)` — a reference to the field being destructively removed. The formula was rewritten to use `PRIORVALUE(StageName)` with a `CASE` expression routing to the per-stage checkbox for each stage:

```
AND(
  ISCHANGED(StageName),
  OR(
    PRIORVALUE(StageName) = "Discovery",
    PRIORVALUE(StageName) = "Requirement Gathering",
    PRIORVALUE(StageName) = "Requirement Documentation",
    PRIORVALUE(StageName) = "User Story Finalization"
  ),
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

The gate now checks the correct per-stage checkbox for the stage being left, rather than the shared flag. The `Current_Stage_Sign_Off_Complete__c` reference is fully removed from this formula.

---

### Flow — Project_Sign_Off_Upload_Document (Rewired)
**File:** `force-app/main/default/flows/Project_Sign_Off_Upload_Document.flow-meta.xml`

The flow previously set `Current_Stage_Sign_Off_Complete__c = true` on the parent Opportunity. It was rewired to route through a Decision element on `{!varSignOff.Stage__c}` and set the matching renamed per-stage checkbox:

| Stage__c value | Field set to true |
|---------------|-------------------|
| Discovery | `Discovery_Sign_Off_Complete__c` |
| Requirement Gathering | `Req_Gathering_Sign_Off_Complete__c` |
| Requirement Documentation | `Req_Documentation_Sign_Off_Complete__c` |
| User Story Finalization | `User_Story_Sign_Off_Complete__c` |

The old `Current_Stage_Sign_Off_Complete__c` assignment element was removed entirely.

---

### Flow — Opportunity_Before_Save (Dead Reference Cleaned)
**File:** `force-app/main/default/flows/Opportunity_Before_Save.flow-meta.xml`

This flow is Obsolete (not active) and was not reactivated. Two dead references to `Current_Stage_Sign_Off_Complete__c` were removed from the flow XML. No logic change — cleanup only.

---

### Permission Sets — Updated to Renamed Field API Names
**Files:**
- `force-app/main/default/permissionsets/Opportunity_RO_PS.permissionset-meta.xml`
- `force-app/main/default/permissionsets/Opportunity_RW_PS.permissionset-meta.xml`
- `force-app/main/default/permissionsets/Opportunity_DELETE_PS.permissionset-meta.xml`

All three permission sets were updated:
- Removed field permission entries for `Current_Stage_Sign_Off_Complete__c` (field is being deleted)
- Updated field permission entries from old API names to the three renamed API names
- `Discovery_Sign_Off_Complete__c` entries were already present and unchanged

---

### Flexipage, Layout, and Translation Cleanup
References to `Current_Stage_Sign_Off_Complete__c` were removed from:

- `force-app/main/default/flexipages/Opportunity_Project_Record_Page.flexipage-meta.xml` — removed `readonly` uiBehavior entry
- `force-app/main/default/layouts/Opportunity-VISEO Project Opportunity Layout.layout-meta.xml` — removed field from layout section
- Object translation file for `Current_Stage_Sign_Off_Complete__c` — deleted entirely

---

### DataCloudGeoLocation Drift Removed
**File removed:** `force-app/main/default/cleanDataServices/DataCloudGeoLocation.cleanDataService-meta.xml`

This file was retrieved from the org as untracked drift. It is not part of this feature and was excluded from the source package to prevent unintended deployment of Data Cloud metadata.

---

## Destructive Deployment Note

`Current_Stage_Sign_Off_Complete__c` must be removed from the org as a separate step after the main components deploy.

**File:** `destructiveChanges/destructiveChanges.xml`

```xml
<types>
  <members>Opportunity.Current_Stage_Sign_Off_Complete__c</members>
  <name>CustomField</name>
</types>
```

**Deployment order (mandatory):**

1. Deploy main components (fields, validation rule, flows, permsets, flexipages, layout) — this removes all formula and flow references to the field.
2. Deploy `destructiveChanges.xml` separately — only after step 1 succeeds.

Deploying the destructive package before the validation rule and flow references are cleared will cause a dependent component deployment error.

---

*Document created by salesforce-documentation agent. For Sprint 3 context, see `docs/sprint3-signoff-refactor-lrp-path-2026-06-21.md`.*
