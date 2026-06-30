# Design Requirements — Receipt Scanner Provider Swap (OpenAI → Gemini)

## WHAT USER REQUESTED

Swap the receipt scanner AI provider from OpenAI GPT-4o to Google Gemini 1.5 Flash, using the existing swappable `ReceiptAiService` pattern. Keep the OpenAI provider and its credentials in place (no deletes). Add new Gemini External/Named Credentials, a new Gemini Apex provider + test, re-point the factory, and grant principal access on the permission set.

---

## FEATURE BRANCH

`feat/receipt-scanner-gemini-provider` (created from `main`).

---

## ROUTING DECISION

- DECLARATIVE_ONLY: **NO**
- COMPLEXITY: **COMPLEX** (Apex + test + External/Named Credential metadata + permission set)

---

## FILES TO CREATE

| # | File | Type |
|---|------|------|
| 1 | `force-app/main/default/externalCredentials/Gemini_API.externalCredential-meta.xml` | ExternalCredential |
| 2 | `force-app/main/default/namedCredentials/Gemini_API.namedCredential-meta.xml` | NamedCredential |
| 3 | `force-app/main/default/classes/GeminiReceiptAiProvider.cls` (+ `-meta.xml`, apiVersion 65.0) | Apex class |
| 4 | `force-app/main/default/classes/GeminiReceiptAiProviderTest.cls` (+ `-meta.xml`, apiVersion 65.0) | Apex test |

## FILES TO MODIFY

| # | File | Change |
|---|------|--------|
| 5 | `force-app/main/default/classes/ReceiptAiServiceFactory.cls` | `createDefaultProvider()` returns `new GeminiReceiptAiProvider()` |
| 6 | `force-app/main/default/permissionsets/Personal_Finance_Tracker_User.permissionset-meta.xml` | Add `externalCredentialPrincipalAccesses` for `Gemini_API-GeminiNamedPrincipal` |
| 7 | `force-app/main/default/classes/OpenAiReceiptAiProviderTest.cls` | **Required fix** — `factoryDefaultProviderIsOpenAi()` currently asserts the factory default IS `OpenAiReceiptAiProvider`. After the swap it must assert `GeminiReceiptAiProvider`. Update or remove this assertion, otherwise the existing test fails on deploy. |

## FILES TO KEEP (DO NOT DELETE OR EDIT)

- `force-app/main/default/classes/OpenAiReceiptAiProvider.cls` (+ `-meta.xml`)
- `force-app/main/default/externalCredentials/OpenAI_API.externalCredential-meta.xml`
- `force-app/main/default/namedCredentials/OpenAI_API.namedCredential-meta.xml`
- `force-app/main/default/classes/ReceiptAiService.cls` (interface — no change)
- `force-app/main/default/classes/ReceiptExtractionResult.cls` (DTO — no change)
- `force-app/main/default/classes/ReceiptScanController.cls` (uses factory — no change)

---

## EXTERNALCREDENTIAL METADATA STRUCTURE

`Gemini_API.externalCredential-meta.xml` — mirror the OpenAI pattern but use the `x-goog-api-key` header instead of `Authorization: Bearer`.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<ExternalCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <authenticationProtocol>Custom</authenticationProtocol>
    <externalCredentialParameters>
        <parameterName>GeminiNamedPrincipal</parameterName>
        <parameterType>NamedPrincipal</parameterType>
        <sequenceNumber>1</sequenceNumber>
    </externalCredentialParameters>
    <externalCredentialParameters>
        <parameterName>x-goog-api-key</parameterName>
        <parameterType>AuthHeader</parameterType>
        <parameterValue>{!$Credential.Gemini_API.ApiKey}</parameterValue>
        <sequenceNumber>2</sequenceNumber>
    </externalCredentialParameters>
    <label>Gemini API</label>
</ExternalCredential>
```

Notes:
- `parameterName` `x-goog-api-key` becomes the literal header name; `parameterValue` is the merge-field value.
- The `ApiKey` custom auth parameter value (the real secret) is set post-deploy in Setup — never committed.

---

## NAMEDCREDENTIAL METADATA STRUCTURE

`Gemini_API.namedCredential-meta.xml`.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<NamedCredential xmlns="http://soap.sforce.com/2006/04/metadata">
    <allowMergeFieldsInBody>false</allowMergeFieldsInBody>
    <allowMergeFieldsInHeader>true</allowMergeFieldsInHeader>
    <calloutStatus>Enabled</calloutStatus>
    <generateAuthorizationHeader>true</generateAuthorizationHeader>
    <label>Gemini API</label>
    <namedCredentialParameters>
        <parameterName>Url</parameterName>
        <parameterType>Url</parameterType>
        <parameterValue>https://generativelanguage.googleapis.com</parameterValue>
    </namedCredentialParameters>
    <namedCredentialParameters>
        <externalCredential>Gemini_API</externalCredential>
        <parameterName>ExternalCredential</parameterName>
        <parameterType>Authentication</parameterType>
    </namedCredentialParameters>
    <namedCredentialType>SecuredEndpoint</namedCredentialType>
</NamedCredential>
```

### Note on `allowFormulasInHttpHeaderAndBody`

- In the **NamedCredential metadata XML**, the elements controlling merge-field/formula evaluation are `allowMergeFieldsInHeader` (header) and `allowMergeFieldsInBody` (body). The Setup UI labels this "Allow Formulas in HTTP Header / Body"; the requested `allowFormulasInHttpHeaderAndBody` maps to these two XML elements.
- Because the `x-goog-api-key` AuthHeader uses the merge field `{!$Credential.Gemini_API.ApiKey}`, set **`allowMergeFieldsInHeader` = `true`**.
- The request body contains no merge fields, so `allowMergeFieldsInBody` stays `false`.
- The OpenAI NamedCredential has both `false` because its Bearer header is resolved entirely by the External Credential AuthHeader parameter. If, during validation, the Gemini header resolves empty at runtime, `allowMergeFieldsInHeader=true` is the corrective setting — keep it true.

---

## GEMINI API REQUEST STRUCTURE

- Endpoint: `callout:Gemini_API/v1beta/models/gemini-1.5-flash:generateContent`
- Method: `POST`, `Content-Type: application/json`, `setTimeout(120000)`
- API key supplied by the External Credential `x-goog-api-key` header (no key in code).
- Build the body with `JSON.createGenerator` (match the OpenAI provider style).

```json
{
  "contents": [
    {
      "parts": [
        {
          "inline_data": {
            "mime_type": "image/jpeg",
            "data": "<base64Image>"
          }
        },
        {
          "text": "Extract receipt data as JSON with fields: merchantName, expenseDate (YYYY-MM-DD), totalAmount (number), suggestedCategory, confidenceScore (0-1). Return only valid JSON."
        }
      ]
    }
  ]
}
```

Notes:
- Gemini sends the image as raw base64 in `inline_data.data` (NOT a `data:` URL like OpenAI). `mime_type` = `contentType`, defaulting to `image/jpeg` when blank.
- Reuse the same PROMPT text as `OpenAiReceiptAiProvider`.

## GEMINI API RESPONSE STRUCTURE

```json
{
  "candidates": [
    {
      "content": {
        "parts": [
          { "text": "{\"merchantName\":\"Corner Cafe\",\"expenseDate\":\"2026-06-15\",\"totalAmount\":12.30,\"suggestedCategory\":\"Dining\",\"confidenceScore\":0.88}" }
        ]
      }
    }
  ]
}
```

- Extract model text from `candidates[0].content.parts[0].text`.
- Pass the extracted text through the same code-fence stripping + JSON parse used by the OpenAI provider.

---

## PROGRAMMATIC IMPLEMENTATION

- `GeminiReceiptAiProvider implements ReceiptAiService` — `extractFromReceipt(String base64Image, String contentType)`.
  - Constants: `ENDPOINT`, `MODEL = 'gemini-1.5-flash'`, reuse `PROMPT`.
  - Blank-image short-circuit → `ReceiptExtractionResult.failure(...)`.
  - Build request with `inline_data` + `text` parts.
  - Non-2xx → failure with status. Parse error → failure. Same try/catch envelope as OpenAI provider.
  - `extractModelText(body)` reads `candidates[0].content.parts[0].text` (null-safe via instanceof checks).
  - Reuse `stripCodeFence`, `asString`, `asDecimal`, `asDate`, `parseExtraction` logic (copy into the new class).
- `ReceiptAiServiceFactory.createDefaultProvider()` → `return new GeminiReceiptAiProvider();`
- `GeminiReceiptAiProviderTest` — mirror `OpenAiReceiptAiProviderTest` with a Gemini response envelope helper:
  - `geminiBody(innerText)` = `{"candidates":[{"content":{"parts":[{"text": <serialized> }]}}]}`.
  - Cover: successful parse, code-fence-wrapped JSON, unparseable content, non-2xx, empty candidates array, blank-image short-circuit, and `factoryDefaultProviderIsGemini` (asserts `createDefaultProvider()` is `GeminiReceiptAiProvider`).
- Update `OpenAiReceiptAiProviderTest.factoryDefaultProviderIsOpenAi()` to reflect the new default (assert Gemini, or remove and rely on the Gemini test). Do not leave a failing assertion.

## DECLARATIVE IMPLEMENTATION

- New `Gemini_API` ExternalCredential + NamedCredential (above).
- Permission set `Personal_Finance_Tracker_User`: add, alongside the existing OpenAI block:

```xml
<externalCredentialPrincipalAccesses>
    <enabled>true</enabled>
    <externalCredentialPrincipal>Gemini_API-GeminiNamedPrincipal</externalCredentialPrincipal>
</externalCredentialPrincipalAccesses>
```

---

## EXECUTION ORDER

1. Create `Gemini_API` ExternalCredential.
2. Create `Gemini_API` NamedCredential (depends on ExternalCredential).
3. Create `GeminiReceiptAiProvider` + test.
4. Update `ReceiptAiServiceFactory` to return Gemini.
5. Update `OpenAiReceiptAiProviderTest` assertion.
6. Add Gemini principal access to permission set (depends on ExternalCredential principal name).
7. Generate `manifest/components-created.xml` with only the components above.
8. Run `sf project deploy validate`, record in `agent-output/validation-results.md`.
9. Commit to `feat/receipt-scanner-gemini-provider`. Do not deploy.

---

## FIELD / NAMING VALIDATION

- No custom fields created. All API names (`Gemini_API`, `GeminiReceiptAiProvider`, `GeminiNamedPrincipal`) within limits. XML filenames match API names.

---

## TASK FOR IMPLEMENTATION AGENT

"""
Implement the full approved scope for this requirement.

Own both declarative metadata (External Credential, Named Credential, permission set) and programmatic changes (Apex provider, test, factory).

Follow project coding standards and use the existing OpenAI provider as the structural template. Keep the OpenAI provider and credentials intact.

Critically: update the existing `OpenAiReceiptAiProviderTest.factoryDefaultProviderIsOpenAi()` assertion so the suite passes after the factory default changes to Gemini.

Implement automated tests and run deployment validation (`sf project deploy validate`); record output in `agent-output/validation-results.md`.

Generate `manifest/components-created.xml`. Commit to the feature branch. Do not deploy.
"""

---

## Approval: APPROVED
