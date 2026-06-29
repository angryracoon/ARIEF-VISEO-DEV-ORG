/**
 * @class        ClaudeReceiptAiProvider
 * @description  Real ReceiptAiService implementation backed by the Anthropic Claude
 *               Vision API. Sends a base64-encoded receipt image to the Messages
 *               endpoint through the Anthropic_API Named Credential and parses the
 *               model's JSON response into a ReceiptExtractionResult.
 *
 *               The API key is injected as the x-api-key header by the External
 *               Credential, so no secret is ever hardcoded here.
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
public with sharing class ClaudeReceiptAiProvider implements ReceiptAiService {

    /** Named Credential endpoint base. */
    private static final String ENDPOINT = 'callout:Anthropic_API/v1/messages';

    /** Anthropic API version header value. */
    private static final String ANTHROPIC_VERSION = '2023-06-01';

    /** Vision-capable Claude model. */
    private static final String MODEL = 'claude-3-5-sonnet-20241022';

    /** Maximum tokens for the completion. */
    private static final Integer MAX_TOKENS = 1024;

    /** Instruction asking the model to return strict JSON. */
    private static final String PROMPT =
        'You are a receipt parsing assistant. Extract the following fields from this ' +
        'receipt image and respond with ONLY a JSON object, no markdown, no commentary. ' +
        'Keys: merchantName (string), expenseDate (ISO date yyyy-MM-dd), totalAmount ' +
        '(number), suggestedCategoryName (string), confidenceScore (number 0-1). ' +
        'If a value cannot be determined, use null.';

    /**
     * @description  Calls Claude Vision with the supplied image and returns the
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
     * @description  Builds the Anthropic Messages request carrying the image and prompt.
     * @param        base64Image  Base64-encoded image bytes.
     * @param        contentType  MIME type of the image.
     * @return       A ready-to-send HttpRequest.
     */
    private HttpRequest buildRequest(String base64Image, String contentType) {
        String mediaType = String.isBlank(contentType) ? 'image/jpeg' : contentType;

        JSONGenerator gen = JSON.createGenerator(false);
        gen.writeStartObject();
        gen.writeStringField('model', MODEL);
        gen.writeNumberField('max_tokens', MAX_TOKENS);
        gen.writeFieldName('messages');
        gen.writeStartArray();
        gen.writeStartObject();
        gen.writeStringField('role', 'user');
        gen.writeFieldName('content');
        gen.writeStartArray();

        // Image block
        gen.writeStartObject();
        gen.writeStringField('type', 'image');
        gen.writeFieldName('source');
        gen.writeStartObject();
        gen.writeStringField('type', 'base64');
        gen.writeStringField('media_type', mediaType);
        gen.writeStringField('data', base64Image);
        gen.writeEndObject();
        gen.writeEndObject();

        // Text block
        gen.writeStartObject();
        gen.writeStringField('type', 'text');
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
        request.setHeader('anthropic-version', ANTHROPIC_VERSION);
        request.setTimeout(120000);
        request.setBody(gen.getAsString());
        return request;
    }

    /**
     * @description  Pulls the first text block out of an Anthropic Messages response body.
     * @param        body  Raw response JSON.
     * @return       The model's text content, or null if not present.
     */
    private String extractModelText(String body) {
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        Object contentObj = parsed.get('content');
        if (!(contentObj instanceof List<Object>)) {
            return null;
        }
        for (Object block : (List<Object>) contentObj) {
            Map<String, Object> blockMap = (Map<String, Object>) block;
            if ('text'.equals(blockMap.get('type')) && blockMap.get('text') != null) {
                return String.valueOf(blockMap.get('text'));
            }
        }
        return null;
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
            result.suggestedCategoryName = asString(data.get('suggestedCategoryName'));
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
