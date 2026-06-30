# Release Notes — Personal Finance Enhancement P1

**Branch:** `feature/2026-06-30-personal-finance-enhancement-p1`
**Sprint:** Personal Finance Enhancement P1
**Date:** 2026-06-30
**Review Verdict:** APPROVED WITH WARNINGS
**Validation:** PASS — 32/32 components, 27 tests (RunSpecifiedTests)

---

## Feature Summary

### Feature 1 — Financial Account Management

Introduces a new `FinancialAccount__c` custom object to track financial accounts (cash, bank, credit card, e-wallet). A lookup field `Expense__c.Financial_Account__c` links expenses to accounts. An Apex trigger (`ExpenseTrigger`) automatically recalculates `Current_Balance__c` on every expense create, update, delete, and undelete. Inactive accounts are blocked from selection by a lookup filter (UI) and a backstop validation rule (API). Three new permission sets enforce RO / RW / DELETE access; the existing `Personal_Finance_Tracker_User` PS is updated to include the new object and field.

### Feature 2 — AI Receipt Scanner

Adds an `Expense Creation Panel` LWC to the Personal Finance home page. Users can create an expense manually (navigates to standard New Expense page) or scan a receipt. The scan workflow captures or uploads a receipt image, sends it to OpenAI GPT-4o Vision via a Named Credential, extracts merchant, date, amount, and suggested category, presents the results for review and edit, then creates the expense via a standard `insert` so existing validation rules and the `Expense_Update_Budget_Spending` flow fire without duplication. The receipt file is attached to the new expense as a `ContentDocumentLink`. The AI provider is swappable; a mock provider is available for test and development environments.

---

## Components Created

### Custom Object
| Component | Type | Notes |
|-----------|------|-------|
| `FinancialAccount__c` | Custom Object | Private sharing, Text name "Account Name" |
| `Account_Type__c` | Field (Picklist, restricted) | Values: Cash, Bank Account, Credit Card, E-Wallet, Others |
| `Current_Balance__c` | Field (Currency 16,2) | Apex-maintained; read-only on layouts |
| `Status__c` | Field (Picklist, restricted) | Values: Active / Inactive, default Active |
| `Notes__c` | Field (Long Text Area 32768) | |
| `FinancialAccount__c` (Tab) | Custom Tab | Added to Personal Finance app nav |

### Custom Field (on existing object)
| Component | Object | Notes |
|-----------|--------|-------|
| `Financial_Account__c` | `Expense__c` | Lookup → FinancialAccount__c, SetNull, lookup filter Status = Active |

### Validation Rule (on existing object)
| Component | Object | Notes |
|-----------|--------|-------|
| `Financial_Account_Must_Be_Active` | `Expense__c` | Backstop for API/non-UI paths; fires on new or changed link to Inactive account |

### Apex
| Component | Type | Notes |
|-----------|------|-------|
| `ExpenseTrigger` | Trigger | after insert/update/delete/undelete on Expense__c |
| `ExpenseTriggerHandler` | Apex Class | Routes DML events; with sharing; recursion-guarded |
| `ExpenseBalanceService` | Apex Class | Aggregate recalculation; single SOQL + single bulk DML; system context for balance write (documented) |
| `ReceiptAiService` | Apex Interface | Provider-swappable AI service contract |
| `ReceiptExtractionResult` | Apex Class | @AuraEnabled DTO: Merchant, Date, TotalAmount, Currency, SuggestedCategory, ConfidenceScore |
| `MockReceiptAiProvider` | Apex Class | Deterministic stub for tests and dev |
| `OpenAiReceiptAiProvider` | Apex Class | OpenAI GPT-4o Vision callout; all failures return structured result (no throws) |
| `ReceiptAiServiceFactory` | Apex Class | Resolves mock vs GPT-4o provider; @TestVisible override |
| `ReceiptScanController` | Apex Class | @AuraEnabled: uploadReceipt, processReceipt, getActiveFinancialAccounts, matchCategory, createExpenseFromReceipt |

### Apex (modified)
| Component | Change |
|-----------|--------|
| `TestDataFactory` | Added Category, FinancialAccount, and Expense factory helpers |

### Apex Tests
| Test Class | Coverage Scope |
|------------|---------------|
| `ExpenseTriggerHandlerTest` | Insert, bulk (200), amount change, reparent, delete, undelete, mixed-account isolation, no-account guard |
| `ReceiptScanControllerTest` | Upload, extraction via mock, account filtering, category match hit/miss/blank, expense creation with attachment and balance assertion, VR enforcement, empty-data guard |
| `OpenAiReceiptAiProviderTest` | Success parse, code-fence JSON, unparseable content, HTTP 500, empty content array, blank-image short-circuit, factory override/default |

### LWC
| Component | Notes |
|-----------|-------|
| `expenseCreationPanel` | Home page entry point — Manual Create / Scan Receipt buttons |
| `receiptScanWorkflow` | Guided multi-step: capture/upload → review/edit → confirm → success |

### Permission Sets
| Component | Type |
|-----------|------|
| `FinancialAccount_RO_PS` | Created — read-only access to FinancialAccount__c |
| `FinancialAccount_RW_PS` | Created — edit access; Current_Balance__c remains read-only |
| `FinancialAccount_DELETE_PS` | Created — additive delete permission (use with RW_PS) |

### Named Credential / External Credential
| Component | Notes |
|-----------|-------|
| `OpenAI_API` (External Credential) | Custom protocol, Bearer token auth |
| `OpenAI_API` (Named Credential) | SecuredEndpoint → https://api.openai.com |

### Metadata Modified
| Component | Change |
|-----------|--------|
| `Personal_Finance` (App) | Added FinancialAccount__c tab to nav |
| `Personal_Finance_Home` (FlexiPage) | Added `c:expenseCreationPanel` to region1 |
| `Expense_Record_Page` (FlexiPage) | Added `Financial_Account__c` field |
| `Personal_Finance_Tracker_User` (Permission Set) | Added FinancialAccount object access + Expense.Financial_Account__c field permission |

---

## Breaking Changes

None. The new `ExpenseTrigger` writes only to `FinancialAccount__c`. The existing `Expense_Update_Budget_Spending` flow writes only to `Budget__c`. No conflict. `CategoryTrigger`, `MonthlyFinanceSummaryBatch`, and all Budget flows are untouched.

---

## Known Warnings (non-blocking)

| ID | Severity | Description | Action |
|----|----------|-------------|--------|
| W1 | Warning | `ReceiptExtractionResult` missing sharing declaration — pure DTO, no runtime risk | Follow-up: add `with sharing` |
| W2 | Warning | `Personal_Finance_Tracker_User` PS missing `Transaction_Type__c` field permission — pre-existing omission, outside this sprint's scope | Follow-up: separate story to add read/edit perm |
| W3 | Warning | LWC Jest coverage minimal — step-progression flow and manual-create navigation path not covered by Jest; Apex controller paths fully covered | Follow-up: expand Jest suites |

---

## Pre-existing Test Failures (not caused by this sprint)

Two test failures appear in full `RunLocalTests` runs against the target org. Both are pre-existing and not related to any change in this branch:

| Test | Root Cause |
|------|------------|
| `MonthlyFinanceSummaryBatchTest.testBudgetClonedAndEmailSent` | Test inserts an Income Expense linked to an Expense Category, violating the pre-existing `Income_Cannot_Use_Expense_Category` validation rule — data bug in the existing test class |
| `MonthlyFinanceSummarySchedulableTest.testScheduleRegistration` | A live "Monthly Finance Summary" job is already scheduled in the org, causing the test to fail on job registration |

These require separate remediation: fix the `MonthlyFinanceSummaryBatchTest` data setup; abort the scheduled job before test runs. They are out of scope for this sprint.

---

## Dependencies

- OpenAI API key required — must be configured in the Named Credential `OpenAI_API` in the target org before deploying. Obtain the key from platform.openai.com → API Keys.
- No other external dependencies introduced.

---

## Deployment Notes

**Manifest:** `manifest/components-created.xml`

**Deploy command (RunSpecifiedTests — validated):**
```
sf project deploy start --manifest manifest/components-created.xml \
  --test-level RunSpecifiedTests \
  --tests ExpenseTriggerHandlerTest \
  --tests ReceiptScanControllerTest \
  --tests OpenAiReceiptAiProviderTest
```

**Do not use RunLocalTests** until the two pre-existing failures listed above are remediated in separate stories.

---

## Post-Deployment Steps

1. **Configure Named Credential** — In the target org, navigate to Setup → External Credentials → `OpenAI_API` → Principal `OpenAINamedPrincipal` → Parameter `ApiKey` and set the value to your OpenAI API key (Bearer token format is handled automatically by the credential). Obtain the key from platform.openai.com → API Keys. The AI Receipt Scanner will not function until this is done.

2. **Assign Permission Sets** — Assign access to users who need Financial Account access:
   - Read-only access: `FinancialAccount_RO_PS`
   - Create/edit access: `FinancialAccount_RW_PS`
   - Delete access: `FinancialAccount_DELETE_PS` (assign alongside `FinancialAccount_RW_PS`)

3. **Verify home page** — Confirm the Expense Creation Panel appears on the Personal Finance home page (region1).

4. **Verify FinancialAccount tab** — Confirm the Financial Account tab is visible in the Personal Finance app nav.
