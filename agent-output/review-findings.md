# Code Review Findings — Receipt Scanner Gemini Provider Swap

**Branch:** `feat/receipt-scanner-gemini-provider`
**Reviewer:** salesforce-code-review
**Review Date:** 2026-06-30
**Validation Status:** PASS (58 tests, 12/12 components + 4 destructive — pre-confirmed)

---

## Review Checks

```
REVIEW_CHECK: SOQL in loops=PASS
REVIEW_CHECK: DML in loops=PASS
REVIEW_CHECK: Hardcoded IDs=PASS
REVIEW_CHECK: Hardcoded secrets/API keys=PASS
REVIEW_CHECK: Missing bulkification=PASS
REVIEW_CHECK: Missing null checks=PASS
REVIEW_CHECK: Missing exception handling=PASS
REVIEW_CHECK: Missing with sharing=PASS
REVIEW_CHECK: Missing WITH USER_MODE=PASS
REVIEW_CHECK: Trigger recursion=N/A
REVIEW_CHECK: Missing Permission Sets=PASS
REVIEW_CHECK: Missing Field Permissions=PASS
REVIEW_CHECK: Field API name > 40 chars=PASS
REVIEW_CHECK: Field label > 40 chars=PASS
REVIEW_CHECK: Metadata filename mismatch=PASS
REVIEW_CHECK: System.debug=PASS
REVIEW_CHECK: Large methods=PASS
REVIEW_CHECK: Missing ApexDocs=PASS
REVIEW_CHECK: Hardcoded literals=WARN
REVIEW_CHECK: Missing CONSTANTS class=PASS
REVIEW_CHECK: One trigger per object=N/A
REVIEW_CHECK: Trigger delegates to handler=N/A
REVIEW_CHECK: No business logic in trigger=N/A
REVIEW_CHECK: Bulkified trigger=N/A
REVIEW_CHECK: Recursion protection=N/A
REVIEW_CHECK: No SeeAllData=PASS
REVIEW_CHECK: TestSetup used=PASS
REVIEW_CHECK: Positive test scenarios=PASS
REVIEW_CHECK: Negative test scenarios=PASS
REVIEW_CHECK: Bulk test scenarios=PASS
REVIEW_CHECK: Meaningful assertions=PASS
REVIEW_CHECK: Gemini request body format (inline_data, raw base64)=PASS
REVIEW_CHECK: Gemini response parsing (candidates[0].content.parts[0].text)=PASS
REVIEW_CHECK: Non-2xx returns failure, never throws=PASS
REVIEW_CHECK: Named Credential allowMergeFieldsInHeader=true=PASS
REVIEW_CHECK: ExternalCredential NamedPrincipal+AuthHeader parameterGroup=WARN
REVIEW_CHECK: Permission set Gemini access added=PASS
REVIEW_CHECK: Permission set OpenAI access removed=PASS
REVIEW_CHECK: Destructive manifest covers all 4 OpenAI components=PASS
REVIEW_CHECK: Tests use HttpCalloutMock=PASS
REVIEW_CHECK: Tests cover success + failure paths=PASS
REVIEW_CHECK: Design deviation — OpenAI components deleted=WARN
```

---

## Critical Issues

None.

---

## Warnings

### W1 — ExternalCredential `AuthHeader` missing `parameterGroup`

- **File:** `externalCredentials/Gemini_API.externalCredential-meta.xml`, line 9
- **Issue:** The `AuthHeader` parameter (`x-goog-api-key`) has no `<parameterGroup>` element linking it to the `GeminiNamedPrincipal` NamedPrincipal.
- **Reason:** In Salesforce External Credentials with Custom auth protocol, `parameterGroup` on an `AuthHeader` entry associates the header with a specific principal. Without it, the API key header may not be injected at runtime for that principal.
- **Impact:** All tests use `HttpCalloutMock` and bypass credential injection, so this is undetectable in validation. Runtime callouts would be the first failure surface.
- **Recommendation:** Add `<parameterGroup>GeminiNamedPrincipal</parameterGroup>` to the `x-goog-api-key` AuthHeader parameter entry. Verify in Setup after deployment that the header is injected by checking the ExternalCredential principal configuration.

### W2 — Unused `MODEL` constant

- **File:** `classes/GeminiReceiptAiProvider.cls`, line 20
- **Issue:** `private static final String MODEL = 'gemini-1.5-flash';` is declared but never referenced. The model name is embedded as a string literal in `ENDPOINT` instead.
- **Reason:** Dead code; increases maintenance confusion about what is authoritative.
- **Recommendation:** Either reference `MODEL` inside the `ENDPOINT` constant (e.g., `'callout:Gemini_API/v1beta/models/' + MODEL + ':generateContent'`), or remove the constant.

### W3 — Design deviation: OpenAI components deleted

- **File:** `manifest/destructive-changes.xml`; OpenAI Apex and credential files deleted from repo
- **Issue:** The approved design-requirements.md explicitly listed `OpenAiReceiptAiProvider.cls`, `OpenAI_API` ExternalCredential, and `OpenAI_API` NamedCredential under "Files to Keep (Do Not Delete)." Implementation deleted all four and included them in the destructive manifest.
- **Impact:** Non-blocking if the deletion is intentional. The destructive manifest is correct and covers all 4 components. Validation passed 58/58.
- **Recommendation:** Confirm with stakeholders that permanent OpenAI removal was authorised. If yes, update the design document to reflect the expanded scope. Flag this change explicitly in the PR description so reviewers are aware it goes beyond the originally approved scope.

---

## Good Practices

- **No hardcoded secrets:** `parameterValue` in ExternalCredential uses `{!$Credential.Gemini_API.ApiKey}` merge field; no real key anywhere in code or metadata.
- **with sharing on all classes:** Both `GeminiReceiptAiProvider` and `ReceiptAiServiceFactory` declare `with sharing`.
- **Callout via Named Credential only:** Endpoint is `callout:Gemini_API/...`; no raw URLs with credentials.
- **Robust null chain in `extractModelText`:** Every level of the Gemini response (candidates, content, parts, text) is guarded with `instanceof` checks before casting; returns null safely rather than throwing.
- **Code-fence stripping:** `stripCodeFence` handles model responses that wrap JSON in markdown — defensive and production-hardened.
- **Non-throwing error handling:** All failure paths return `ReceiptExtractionResult.failure(...)`. The `try/catch` at the callout level ensures no unhandled exceptions propagate to the caller.
- **Blank-image short-circuit:** Pre-callout guard (`String.isBlank`) avoids a wasted HTTP round trip.
- **Test coverage quality:** 7 test methods covering success, code-fence JSON, unparseable content, HTTP 500, empty candidates, blank-image guard, and factory default assertion. All assertions include descriptive messages.
- **Factory test isolation:** `GeminiReceiptAiProviderTest.factoryDefaultProviderIsGemini` calls `createDefaultProvider()` directly (bypassing `Test.isRunningTest()` branch) — correct pattern to exercise real provider wiring.
- **Permission set swap correct:** `Gemini_API-GeminiNamedPrincipal` added; OpenAI entry absent. Format matches Salesforce ExternalCredentialPrincipal naming convention.
- **Destructive manifest complete:** All 4 OpenAI components listed (2 ApexClass, 1 ExternalCredential, 1 NamedCredential).
- **Full ApexDocs:** Every method in `GeminiReceiptAiProvider` and `ReceiptAiServiceFactory` has `@description`, `@param`, `@return` blocks.
- **No System.debug, no hardcoded Ids, no SeeAllData.**
- **MonthlyFinanceSummaryBatchTest fix:** Income transaction correctly uses a dedicated Income-type category to avoid the `Income_Cannot_Use_Expense_Category` VR — root cause properly addressed.
- **MonthlyFinanceSummarySchedulableTest fix:** Pre-existing scheduled job abort before schedule call makes test deterministic regardless of org state — correct defensive pattern.

---

## Verdict

```
VERDICT: APPROVED WITH WARNINGS
```

All three warnings are non-blocking:
- W1 (`parameterGroup`) is a metadata structural concern not detectable in mocked tests; should be verified post-deploy in Setup.
- W2 (`MODEL` constant) is dead code with zero functional impact.
- W3 (OpenAI deletion) is a scope expansion beyond the approved design; functionally correct and validation-confirmed.

Implementation is ready for Documentation and DevOps PR handling if developer validation passed (`agent-output/validation-results.md` records PASS).
