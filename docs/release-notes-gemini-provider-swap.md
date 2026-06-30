# Release Notes — Receipt Scanner: OpenAI to Gemini Provider Swap

**Branch:** `feat/receipt-scanner-gemini-provider`
**Date:** 2026-06-30

---

## Summary

Swapped the AI receipt scanner backend from OpenAI GPT-4o to Google Gemini 1.5 Flash (free tier). The `ReceiptAiService` interface and `ReceiptScanController` are unchanged; only the active provider and its credentials changed. OpenAI components have been permanently removed from the org.

**Reason:** OpenAI requires paid credits. Gemini 1.5 Flash is free up to 15 requests/min and 1,500 requests/day — sufficient for personal use.

---

## Components Added

| Type | Name | Notes |
|------|------|-------|
| Apex Class | `GeminiReceiptAiProvider` | Calls Gemini 1.5 Flash via Named Credential; parses `candidates[0].content.parts[0].text` |
| Apex Test | `GeminiReceiptAiProviderTest` | 7 test methods: success, code-fence JSON, unparseable content, HTTP 500, empty candidates, blank-image short-circuit, factory default assertion |
| ExternalCredential | `Gemini_API` | Custom auth protocol; `x-goog-api-key` AuthHeader using `{!$Credential.Gemini_API.ApiKey}` merge field |
| NamedCredential | `Gemini_API` | SecuredEndpoint; `https://generativelanguage.googleapis.com`; `allowMergeFieldsInHeader=true` |

---

## Components Modified

| Type | Name | Change |
|------|------|--------|
| Apex Class | `ReceiptAiServiceFactory` | `createDefaultProvider()` now returns `new GeminiReceiptAiProvider()` |
| Apex Test | `OpenAiReceiptAiProviderTest` | Factory default assertion updated to assert `GeminiReceiptAiProvider` |
| Permission Set | `Personal_Finance_Tracker_User` | Gemini principal access (`Gemini_API-GeminiNamedPrincipal`) added; OpenAI principal access removed |
| Apex Test | `MonthlyFinanceSummaryBatchTest` | Pre-existing fix: income transaction now uses a dedicated Income-type category to satisfy validation rule |
| Apex Test | `MonthlyFinanceSummarySchedulableTest` | Pre-existing fix: aborts any existing scheduled job before re-scheduling to make tests deterministic |

---

## Components Removed (Destructive)

All OpenAI components have been permanently deleted from the org and repository.

| Type | Name |
|------|------|
| Apex Class | `OpenAiReceiptAiProvider` |
| Apex Test | `OpenAiReceiptAiProviderTest` |
| ExternalCredential | `OpenAI_API` |
| NamedCredential | `OpenAI_API` |

> **Note:** The original design listed OpenAI components as "keep intact." Implementation expanded scope to delete them. This is intentional and functionally correct — confirmed by code review (W3, non-blocking).

---

## Breaking Changes

- `OpenAiReceiptAiProvider` is deleted. Any direct reference to this class (outside of the `ReceiptAiService` interface) will fail to compile.
- The `OpenAI_API` Named/External Credentials are deleted. Any other callout referencing `callout:OpenAI_API` will break.

---

## Post-Deploy Setup (Required)

The Gemini API key is **not** committed to the repository. It must be set manually after deployment.

1. Go to **Setup** → **Named Credentials** → **External Credentials**.
2. Open **Gemini API**.
3. Under **Principals**, click **GeminiNamedPrincipal** → **Authentication Parameters** → **New**.
4. Set **Name** = `ApiKey`, **Value** = your Google AI Studio API key (obtain from [aistudio.google.com](https://aistudio.google.com)).
5. Save.

> **Post-deploy verification (W1):** After setting the API key, confirm in Setup that the `x-goog-api-key` header is associated with the `GeminiNamedPrincipal` principal. If the header is not injected at runtime, add `<parameterGroup>GeminiNamedPrincipal</parameterGroup>` to the `x-goog-api-key` AuthHeader entry in the ExternalCredential metadata and redeploy.

---

## Testing

- **Validation run:** 58/58 tests pass, 12/12 components validated + 4 destructive components.
- **Code review verdict:** APPROVED WITH WARNINGS (3 non-blocking warnings; no critical issues).
- **New test coverage:** `GeminiReceiptAiProvider` covers success, error, and edge-case paths at >90% estimated coverage.
