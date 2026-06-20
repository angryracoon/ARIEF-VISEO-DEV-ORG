# Sprint 2 Corrections — Project Delivery Management
**Branch:** `feature/2026-06-20-project-delivery-sprint2-corrections`
**Date:** 2026-06-20
**API Version:** 65.0
**Route:** Admin-only (declarative metadata, no Apex or LWC)

---

## Background

Sprint 1 deployed the core Project Delivery Management objects, fields, flows, permission sets, and initial flexipages. Sprint 2 corrects gaps identified after that deployment:

- Page Layouts were missing for all 4 objects
- Lightning Record Pages (flexipages) were incomplete — the Opportunity page had only the path component; the Sign Off page was missing the Upload Sign-Off Document flow button
- The Opportunity StageName picklist needed VISEO project stages configured with correct won/closed flags
- Activities and Sprints lacked a "Closed" terminal status distinct from "Completed" or "Cancelled"
- The `Total_Open_Activities__c` roll-up needed to exclude Closed activities so a sprint can be set to Closed when all activities are resolved
- No validation prevented closing a sprint while open activities remained
- The Opportunity object label had not been renamed to "Project Opportunity"

---

## Components Changed

### S2.1 — Page Layouts (4 new files)

**File locations:** `force-app/main/default/layouts/`

| Layout File | Object |
|---|---|
| `Opportunity-VISEO Project Opportunity Layout.layout-meta.xml` | Opportunity |
| `Project_Sign_Off__c-Project Sign Off Layout.layout-meta.xml` | Project_Sign_Off__c |
| `Project_Sprint__c-Project Sprint Layout.layout-meta.xml` | Project_Sprint__c |
| `Project_Activity__c-Project Activity Layout.layout-meta.xml` | Project_Activity__c |

**Opportunity layout** — 4 sections:

| Section | Fields | Behavior |
|---|---|---|
| Project Information | Project_Description__c, Project_Scope__c | Edit |
| Key Dates | Start_Date__c, Planned_Go_Live_Date__c, Actual_Go_Live_Date__c | Edit |
| Mandays | Planned_Mandays__c, Actual_Mandays__c (left); Total_Planned_Mandays__c, Total_Actual_Mandays__c (right-readonly) | Mixed |
| Project Status | Project_Health__c, Delivery_Methodology__c, Current_Stage_Sign_Off_Complete__c (readonly), StageName | Mixed |

Related lists: Project Sprints, Project Sign Offs, Opportunity Team Members, Activity, History.

**Project Sign Off layout** — 2 sections: Sign Off Information (Opportunity, Stage, Sign_Off_Status__c), Approval (Approved_By__c, Approval_Date__c). Related: Files, Activity, History.

**Project Sprint layout** — 5 sections: Sprint Information (Opportunity, Sprint_Number__c, Sprint_Goal__c, Sprint_Status__c), Dates, Mandays (Planned + Actual), Sprint Description, Activity Summary (5 rollup fields readonly). Related: Project Activities, Activity, History.

**Project Activity layout** — 5 sections: Activity Information (Project_Sprint__c, Activity_Type__c, Activity_Status__c), Assignment (Assigned_To__c, Reviewer__c), Dates, Mandays, Activity Updates. Related: Activity, History.

---

### S2.2 — Lightning Record Pages / Flexipages (all 4 rebuilt)

**File locations:** `force-app/main/default/flexipages/`

All 4 flexipages use `flexipage:recordHomeWithSubheaderTemplateDesktop`.

| Page | Subheader | Left Region | Right Region |
|---|---|---|---|
| Opportunity | pathAssistant (linear) | highlightsPanel + Project Details fieldSection | Activity Metrics fieldSection (Total_Sprints__c, Total_Planned_Mandays__c, Total_Actual_Mandays__c) + Project Sprints, Sign Offs, Team Members related lists |
| Project Sign Off | highlightsPanel | Sign Off Details fieldSection + flowruntime:flowRuntimeForFlexiPage (Project_Sign_Off_Upload_Document, passes recordId) | Files (AttachedContentDocuments) related list |
| Project Sprint | highlightsPanel | Sprint Details fieldSection + Project Activities (Project_Activities__r) related list | Activity Metrics fieldSection (Total_Activities__c, Total_Completed_Activities__c, Total_Open_Activities__c) |
| Project Activity | highlightsPanel | Activity Details fieldSection | forceChatter:feed |

---

### S2.3 — OpportunityStage StandardValueSet

**File:** `force-app/main/default/standardValueSets/OpportunityStage.standardValueSet-meta.xml`

Nine VISEO stages configured as **active**:

| Stage | Probability | Forecast Category | Won | Closed |
|---|---|---|---|---|
| Discovery | 10% | Pipeline | false | false |
| Requirement Gathering | 20% | Pipeline | false | false |
| Requirement Documentation | 30% | Pipeline | false | false |
| User Story Finalization | 40% | Pipeline | false | false |
| In Development | 50% | Pipeline | false | false |
| QA | 60% | Pipeline | false | false |
| UAT | 75% | Pipeline | false | false |
| Live | 100% | Closed | **true** | **true** |
| AMS | 100% | Closed | **true** | **true** |

OOB stages (Prospecting, Qualification, Needs Analysis, Value Proposition, Id. Decision Makers, Perception Analysis, Proposal/Price Quote, Negotiation/Review) set to **active=false**.

Closed Won and Closed Lost set to **active=false** (preserved in file for platform integrity).

RecordType `VISEO_Project_Opportunity` has explicit StageName picklist override with only the 9 VISEO stages visible.

---

### S2.4 — Picklist Values: "Closed" Status

**S2.4a — Activity_Status__c on Project_Activity__c**
**File:** `force-app/main/default/objects/Project_Activity__c/fields/Activity_Status__c.field-meta.xml`

7 values: Not Started, In Progress, In Review, Completed, Blocked, Cancelled, **Closed** (new).

**S2.4b — Sprint_Status__c on Project_Sprint__c**
**File:** `force-app/main/default/objects/Project_Sprint__c/fields/Sprint_Status__c.field-meta.xml`

5 values: Planning, In Progress, Complete, Cancelled, **Closed** (new).

---

### S2.5 — Total_Open_Activities__c Roll-Up Filter

**File:** `force-app/main/default/objects/Project_Sprint__c/fields/Total_Open_Activities__c.field-meta.xml`

Roll-up filter updated with 3 criteria (COUNT excludes):
1. Activity_Status__c notEqual Completed
2. Activity_Status__c notEqual Cancelled
3. Activity_Status__c notEqual **Closed** (new)

This ensures activities in any terminal state (Completed, Cancelled, or Closed) do not count toward the open activities total, allowing a sprint to be closed once all activities are resolved.

---

### S2.6 — Validation Rule: Prevent_Close_With_Open_Activities

**File:** `force-app/main/default/objects/Project_Sprint__c/validationRules/Prevent_Close_With_Open_Activities.validationRule-meta.xml`

| Property | Value |
|---|---|
| Object | Project_Sprint__c |
| API Name | Prevent_Close_With_Open_Activities |
| Active | true |
| Error Location | Top of page |
| Error Message | Cannot close this sprint — there are still open project activities. Please close all activities before closing the sprint. |
| Formula | `ISPICKVAL(Sprint_Status__c, "Closed") && Total_Open_Activities__c > 0` |

Prevents saving a Project Sprint when Sprint_Status__c is "Closed" and Total_Open_Activities__c is greater than zero.

---

### S2.7 — Opportunity Object Translation

**File:** `force-app/main/default/objectTranslations/Opportunity-en_US.objectTranslation-meta.xml`

Renames the Opportunity object label in en_US locale:
- **label:** Project Opportunity
- **pluralLabel:** Project Opportunities
- **startsWith:** Consonant

---

## Security Model

No changes to permission sets, profiles, or sharing rules in this sprint. The Opportunity layout is assigned to the `VISEO_Project_Opportunity` record type. Access continues to be governed by the permission sets deployed in Sprint 1.

---

## File Locations Summary

```
force-app/main/default/
  layouts/
    Opportunity-VISEO Project Opportunity Layout.layout-meta.xml       (NEW)
    Project_Sign_Off__c-Project Sign Off Layout.layout-meta.xml        (NEW)
    Project_Sprint__c-Project Sprint Layout.layout-meta.xml            (NEW)
    Project_Activity__c-Project Activity Layout.layout-meta.xml        (NEW)
  flexipages/
    Opportunity_Project_Record_Page.flexipage-meta.xml                 (REBUILT)
    Project_Sprint_Record_Page.flexipage-meta.xml                      (REBUILT)
    Project_Activity_Record_Page.flexipage-meta.xml                    (REBUILT)
    Project_Sign_Off_Record_Page.flexipage-meta.xml                    (REBUILT)
  standardValueSets/
    OpportunityStage.standardValueSet-meta.xml                         (UPDATED)
  objects/
    Project_Activity__c/fields/Activity_Status__c.field-meta.xml       (UPDATED — added Closed)
    Project_Sprint__c/fields/Sprint_Status__c.field-meta.xml           (UPDATED — added Closed)
    Project_Sprint__c/fields/Total_Open_Activities__c.field-meta.xml   (UPDATED — 3rd filter)
    Project_Sprint__c/validationRules/
      Prevent_Close_With_Open_Activities.validationRule-meta.xml       (NEW)
    Opportunity/recordTypes/
      VISEO_Project_Opportunity.recordType-meta.xml                    (UPDATED — StageName override)
  objectTranslations/
    Opportunity-en_US.objectTranslation-meta.xml                       (NEW)
```
