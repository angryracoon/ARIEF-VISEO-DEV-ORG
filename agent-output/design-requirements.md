# Design Requirements — Opportunity Probability Auto-Update on Stage Change

**Date:** 2026-06-26
**Branch:** `feat/opportunity-probability-auto-update`
**API Version:** 65.0

---

## Context and Key Finding

The org uses two distinct Opportunity record types:

1. **VISEO_Project_Opportunity** — uses the `VISEO_Sales_Process` business process with delivery-centric stages: Discovery, Requirement Gathering, Requirement Documentation, User Story Finalization, AMS, In Development, Live, QA, UAT. These stages have no probability semantics and are not in scope for this feature.

2. **Default/Standard Opportunity** — uses standard Salesforce stage picklist values (Qualification, Proposal/Price Quote, Id. Decision Makers, Perception Analysis, Value Proposition, Needs Analysis, Negotiation/Review, Closed Won, Closed Lost). The requirement maps to a simplified 6-stage subset of these.

**Critical insight:** Salesforce already has a built-in Stage→Probability mapping via the `ForecastCategoryName` and `defaultProbability` on stage picklist values. However, the behavior is: the standard SF UI syncs Probability when Stage changes **only if the user has not manually edited Probability** (the "Override" checkbox). The acceptance criteria explicitly states "Existing manually entered Probability should be overwritten when Stage changes," which the standard picklist config does NOT guarantee in all scenarios.

Therefore: **Option B — Before Save Flow** is required to guarantee overwrite on every stage change.

---

## Chosen Approach: Option B — Record-Triggered Flow (Before Save)

**Rationale:**
- Option A (picklist `defaultProbability`) does not overwrite a manually-entered Probability in all cases — Salesforce only resets Probability automatically when the user has not unlocked the field.
- Option B (Before Save Flow) unconditionally sets `Probability` on every `StageName` change, satisfying the "overwrite manual entry" acceptance criterion.
- A Before Save flow is the simplest declarative mechanism that covers this requirement without Apex.
- This approach aligns with the project's declarative-first preference (memory: always prefer declarative over Apex when viable).

---

## Stage → Probability Mapping

| Stage            | Probability |
|------------------|-------------|
| Qualification    | 10          |
| Discovery        | 25          |
| Proposal         | 50          |
| Negotiation      | 75          |
| Closed Won       | 100         |
| Closed Lost      | 0           |

**Note on stage names:** The requirement uses simplified names. The actual Salesforce picklist values in a standard org may use longer names (e.g., "Proposal/Price Quote", "Negotiation/Review"). The flow must use the exact API values as they appear in the org's StageName picklist. If the org's stage values differ (e.g., use "Proposal/Price Quote" instead of "Proposal"), the developer must verify and match exactly. Since the VISEO org only has VISEO_Project_Opportunity as a custom record type, these 6 stages are presumed to be on the standard default record type.

---

## Components to Create / Update

### Flow: `Opportunity_Before_Save` (existing — revive with new logic)
- **Type:** Record-Triggered Flow (Before Save)
- **Object:** Opportunity
- **Trigger:** Create and Update
- **Start element:** NO entry condition / filterFormula — start is unconditional
- **Structure:**
  1. **Start** → Decision
  2. **Decision** `Stage Changed?`
     - **Yes** outcome: `frmStageChanged` EqualTo `true` → Assignment
     - **No** (default): → End
  3. **Assignment** `Assign Probability`: sets `$Record.Probability` = `frmProbability`

### Formula Variables

**`frmStageChanged`** — Boolean
```
ISCHANGED({!$Record.StageName})
```

**`frmProbability`** — Number (0 decimal places)
```
IF(ISPICKVAL({!$Record.StageName}, "Qualification"), 10,
IF(ISPICKVAL({!$Record.StageName}, "Discovery"), 25,
IF(ISPICKVAL({!$Record.StageName}, "Proposal"), 50,
IF(ISPICKVAL({!$Record.StageName}, "Negotiation"), 75,
IF(ISPICKVAL({!$Record.StageName}, "Closed Won"), 100,
IF(ISPICKVAL({!$Record.StageName}, "Closed Lost"), 0,
{!$Record.Probability}))))))
```
The final fallback `{!$Record.Probability}` preserves the existing value for unmatched stages (e.g., VISEO delivery stages).

**Implementation file:**
`force-app/main/default/flows/Opportunity_Before_Save.flow-meta.xml`

---

## Existing Automation Compatibility

### `Opportunity_Before_Save.flow-meta.xml`
- Status: **Obsolete/InvalidDraft** — this flow has no active logic (all assignments were removed). It will not conflict. No changes needed.

### `Opportunity_After_Save.flow-meta.xml`
- Status: **Active** — triggers on StageName change to specific VISEO delivery stages (Discovery, Requirement Gathering, Requirement Documentation, User Story Finalization). Creates Project_Sign_Off__c records.
- **Interaction:** No conflict. The new Probability Sync flow runs Before Save (different trigger point). The After Save flow is not affected by Probability changes.

### Validation Rules
- `CloseDate_Required_For_Closed_Won.validationRule-meta.xml` — requires CloseDate when Stage = Closed Won. No conflict; Probability change does not affect CloseDate.
- `Prevent_CloseDate_Change_After_ClosedWon.validationRule-meta.xml` — prevents CloseDate modification after Closed Won. No conflict.
- `Sign_Off_Required_Before_Stage_Advance.validationRule-meta.xml` — gates stage advances on sign-off checkboxes. No conflict; runs independently on stage change.

### VISEO_Project_Opportunity Stages
The new flow's fallback (`{!$Record.Probability}` when no match) ensures VISEO delivery stages (AMS, In Development, QA, UAT, Live, Requirement Gathering, Requirement Documentation, User Story Finalization) are untouched. The VISEO_Project_Opportunity record type does not use Probability for forecasting, so no impact.

---

## Implementation Notes for Developer Agent

1. Update `force-app/main/default/flows/Opportunity_Before_Save.flow-meta.xml` — revive the existing Obsolete flow.
2. Start element must have NO `filterFormula` / entry condition.
3. Add Boolean formula `frmStageChanged` = `ISCHANGED({!$Record.StageName})`.
4. Add Decision element `Stage_Changed` with Yes outcome checking `frmStageChanged EqualTo true`.
5. Add Number formula `frmProbability` (scale 0) with the IF/ISPICKVAL chain above.
6. Add Assignment element `Assign_Probability` setting `$Record.Probability` = `frmProbability`.
7. `<status>Active</status>` — deploy as active.
6. Verify exact stage API values in the org before implementing. If the standard picklist uses "Proposal/Price Quote" or "Negotiation/Review", update the ISPICKVAL values accordingly. Use `sf data query --query "SELECT MasterLabel FROM OpportunityStage" --target-org "ARIEF VISEO DEV ORG"` to confirm.
7. Do NOT modify any existing flows, validation rules, or the VISEO_Sales_Process business process.

---

## Execution Order

1. Developer: create `Opportunity_Probability_Sync.flow-meta.xml`
2. Code review
3. SF CLI validation: `sf project deploy validate --target-org "ARIEF VISEO DEV ORG"`
4. PR creation and merge

NEXT_AGENT: salesforce-developer
