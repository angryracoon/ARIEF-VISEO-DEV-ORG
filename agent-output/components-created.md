# Components Created / Modified — Receipt Scanner Gemini Provider Swap

Branch: `feat/receipt-scanner-gemini-provider`
Manifest: `manifest/components-created.xml`

## Apex Classes (created)
- `GeminiReceiptAiProvider` — ReceiptAiService impl for Google Gemini 1.5 Flash
  (generateContent callout via Gemini_API Named Credential, raw base64 inline_data)
- `GeminiReceiptAiProviderTest` — mock HTTP callout tests

## Apex Classes (modified)
- `ReceiptAiServiceFactory` — createDefaultProvider() now returns GeminiReceiptAiProvider
- `OpenAiReceiptAiProviderTest` — factory default assertion updated to assert Gemini

## Metadata (created)
- External Credential: `Gemini_API` — Custom protocol, `x-goog-api-key` AuthHeader
- Named Credential: `Gemini_API` — SecuredEndpoint → https://generativelanguage.googleapis.com,
  allowMergeFieldsInHeader=true

## Metadata (modified)
- Permission Set: `Personal_Finance_Tracker_User` — added external credential principal
  access for `Gemini_API-GeminiNamedPrincipal` (existing OpenAI entry retained)

## Kept Intact (no change)
- OpenAiReceiptAiProvider + OpenAI_API external/named credentials
- ReceiptAiService, ReceiptExtractionResult, ReceiptScanController

## Notes
- API key (Gemini_API.ApiKey custom auth parameter) is set post-deploy in Setup — never committed.
