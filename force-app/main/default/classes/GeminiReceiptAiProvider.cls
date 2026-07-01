/**
 * @class        GeminiReceiptAiProvider
 * @description  Real ReceiptAiService implementation backed by the Google Gemini
 *               2.0 Flash multimodal API. Sends a base64-encoded receipt image to
 *               the generateContent endpoint through the Gemini_API Named Credential
 *               and parses the model's JSON response into a ReceiptExtractionResult.
 *
 *               The API key is injected as the x-goog-api-key header by the External
 *               Credential, so no secret is ever hardcoded here.
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
public with sharing class GeminiReceiptAiProvider implements ReceiptAiService {

    /** Named Credential endpoint for the Gemini generateContent API. */
    private static final String ENDPOINT =
        'callout:Gemini_API/v1beta/models/gemini-2.5-flash:generateContent';

    /** Instruction asking the model to return strict JSON. */
    private static final String PROMPT =
        'Extract receipt data as JSON with fields: merchantName, expenseDate ' +
        '(YYYY-MM-DD), totalAmount (number), suggestedCategory, confidenceScore ' +
        '(0-1). Return only valid JSON.';

    /**
     * @description  Calls Gemini 2.0 Flash with the supplied image and returns the
     *               parsed extraction result. Any callout or parsing failure is
     *               returned as an unsuccessful result rather than thrown.
     * @param        base64Image  Base64-encoded image bytes.
     * @param        contentType  MIME type of the image (e.g. image/jpeg).
     * @return       A ReceiptExtractionResult.
     */
    public ReceiptExtractionResult extractFromReceipt(String base64Image, String contentType) {
        if (String.isBlank(base64Image)) {
            return ReceiptExtractionResult.failure('No image data was provided to the AI provider.');
        }

        try {
            HttpRequest request = buildRequest(base64Image, contentType);
            HttpResponse response = new Http().send(request);

            if (response.getStatusCode() < 200 || response.getStatusCode() >= 300) {
                return ReceiptExtractionResult.failure(
                    'AI service returned status ' + response.getStatusCode() + ': ' + response.getStatus()
                );
            }

            String modelText = extractModelText(response.getBody());
            if (String.isBlank(modelText)) {
                return ReceiptExtractionResult.failure('AI service response did not contain any content.');
            }
            return parseExtraction(modelText);
        } catch (Exception e) {
            return ReceiptExtractionResult.failure('AI service call failed: ' + e.getMessage());
        }
    }

    /**
     * @description  Builds the Gemini generateContent request carrying the image
     *               (as raw base64 inline_data) and the extraction prompt.
     * @param        base64Image  Base64-encoded image bytes.
     * @param        contentType  MIME type of the image.
     * @return       A ready-to-send HttpRequest.
     */
    private HttpRequest buildRequest(String base64Image, String contentType) {
        String mediaType = String.isBlank(contentType) ? 'image/jpeg' : contentType;

        JSONGenerator gen = JSON.createGenerator(false);
        gen.writeStartObject();
        gen.writeFieldName('contents');
        gen.writeStartArray();
        gen.writeStartObject();
        gen.writeFieldName('parts');
        gen.writeStartArray();

        // Image block (raw base64, no data: URL prefix).
        gen.writeStartObject();
        gen.writeFieldName('inline_data');
        gen.writeStartObject();
        gen.writeStringField('mime_type', mediaType);
        gen.writeStringField('data', base64Image);
        gen.writeEndObject();
        gen.writeEndObject();

        // Text block.
        gen.writeStartObject();
        gen.writeStringField('text', PROMPT);
        gen.writeEndObject();

        gen.writeEndArray();
        gen.writeEndObject();
        gen.writeEndArray();
        gen.writeEndObject();

        HttpRequest request = new HttpRequest();
        request.setEndpoint(ENDPOINT);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(120000);
        request.setBody(gen.getAsString());
        return request;
    }

    /**
     * @description  Pulls the model text out of a Gemini generateContent response
     *               body (candidates[0].content.parts[0].text).
     * @param        body  Raw response JSON.
     * @return       The model's text content, or null if not present.
     */
    private String extractModelText(String body) {
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        Object candidatesObj = parsed.get('candidates');
        if (!(candidatesObj instanceof List<Object>) || ((List<Object>) candidatesObj).isEmpty()) {
            return null;
        }
        Map<String, Object> firstCandidate = (Map<String, Object>) ((List<Object>) candidatesObj).get(0);
        Object contentObj = firstCandidate.get('content');
        if (!(contentObj instanceof Map<String, Object>)) {
            return null;
        }
        Object partsObj = ((Map<String, Object>) contentObj).get('parts');
        if (!(partsObj instanceof List<Object>) || ((List<Object>) partsObj).isEmpty()) {
            return null;
        }
        Object firstPartObj = ((List<Object>) partsObj).get(0);
        if (!(firstPartObj instanceof Map<String, Object>)) {
            return null;
        }
        Object textObj = ((Map<String, Object>) firstPartObj).get('text');
        return textObj == null ? null : String.valueOf(textObj);
    }

    /**
     * @description  Parses the model's JSON text into a ReceiptExtractionResult.
     *               Tolerates code-fence wrapping around the JSON.
     * @param        modelText  Raw text returned by the model.
     * @return       A populated ReceiptExtractionResult.
     */
    private ReceiptExtractionResult parseExtraction(String modelText) {
        try {
            String payload = stripCodeFence(modelText);
            Map<String, Object> data = (Map<String, Object>) JSON.deserializeUntyped(payload);

            ReceiptExtractionResult result = new ReceiptExtractionResult();
            result.success = true;
            result.merchantName = asString(data.get('merchantName'));
            result.suggestedCategoryName = asString(
                data.containsKey('suggestedCategory') ? data.get('suggestedCategory') : data.get('suggestedCategoryName')
            );
            result.expenseDate = asDate(data.get('expenseDate'));
            result.totalAmount = asDecimal(data.get('totalAmount'));
            result.confidenceScore = asDecimal(data.get('confidenceScore'));
            return result;
        } catch (Exception e) {
            return ReceiptExtractionResult.failure('Could not parse AI response: ' + e.getMessage());
        }
    }

    /**
     * @description  Removes a leading/trailing markdown code fence if the model wrapped its JSON.
     * @param        text  Raw model text.
     * @return       The inner content suitable for JSON parsing.
     */
    private String stripCodeFence(String text) {
        String trimmed = text.trim();
        if (trimmed.startsWith('```')) {
            Integer firstNewline = trimmed.indexOf('\n');
            if (firstNewline > -1) {
                trimmed = trimmed.substring(firstNewline + 1);
            }
            if (trimmed.endsWith('```')) {
                trimmed = trimmed.substring(0, trimmed.length() - 3);
            }
        }
        return trimmed.trim();
    }

    /**
     * @description  Null-safe String conversion.
     * @param        value  Raw value.
     * @return       String value or null.
     */
    private String asString(Object value) {
        return value == null ? null : String.valueOf(value);
    }

    /**
     * @description  Null-safe Decimal conversion.
     * @param        value  Raw value.
     * @return       Decimal value or null.
     */
    private Decimal asDecimal(Object value) {
        if (value == null) {
            return null;
        }
        return Decimal.valueOf(String.valueOf(value));
    }

    /**
     * @description  Null-safe ISO Date conversion.
     * @param        value  Raw value (yyyy-MM-dd).
     * @return       Date value or null.
     */
    private Date asDate(Object value) {
        if (value == null) {
            return null;
        }
        return Date.valueOf(String.valueOf(value));
    }
}
