/**
 * @class        OpenAiReceiptAiProvider
 * @description  Real ReceiptAiService implementation backed by the OpenAI GPT-4o
 *               Vision API. Sends a base64-encoded receipt image to the Chat
 *               Completions endpoint through the OpenAI_API Named Credential and
 *               parses the model's JSON response into a ReceiptExtractionResult.
 *
 *               The API key is injected as the Authorization Bearer header by the
 *               External Credential, so no secret is ever hardcoded here.
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
public with sharing class OpenAiReceiptAiProvider implements ReceiptAiService {

    /** Named Credential endpoint for the Chat Completions API. */
    private static final String ENDPOINT = 'callout:OpenAI_API/v1/chat/completions';

    /** Vision-capable GPT-4o model. */
    private static final String MODEL = 'gpt-4o';

    /** Maximum tokens for the completion. */
    private static final Integer MAX_TOKENS = 500;

    /** Instruction asking the model to return strict JSON. */
    private static final String PROMPT =
        'Extract receipt data as JSON with fields: merchantName, expenseDate ' +
        '(YYYY-MM-DD), totalAmount (number), suggestedCategory, confidenceScore ' +
        '(0-1). Return only valid JSON.';

    /**
     * @description  Calls GPT-4o Vision with the supplied image and returns the
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
     * @description  Builds the OpenAI Chat Completions request carrying the image
     *               (as a data URL) and the extraction prompt.
     * @param        base64Image  Base64-encoded image bytes.
     * @param        contentType  MIME type of the image.
     * @return       A ready-to-send HttpRequest.
     */
    private HttpRequest buildRequest(String base64Image, String contentType) {
        String mediaType = String.isBlank(contentType) ? 'image/jpeg' : contentType;
        String dataUrl = 'data:' + mediaType + ';base64,' + base64Image;

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
        gen.writeStringField('type', 'image_url');
        gen.writeFieldName('image_url');
        gen.writeStartObject();
        gen.writeStringField('url', dataUrl);
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
        request.setTimeout(120000);
        request.setBody(gen.getAsString());
        return request;
    }

    /**
     * @description  Pulls the assistant message content out of an OpenAI Chat
     *               Completions response body (choices[0].message.content).
     * @param        body  Raw response JSON.
     * @return       The model's text content, or null if not present.
     */
    private String extractModelText(String body) {
        Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
        Object choicesObj = parsed.get('choices');
        if (!(choicesObj instanceof List<Object>) || ((List<Object>) choicesObj).isEmpty()) {
            return null;
        }
        Map<String, Object> firstChoice = (Map<String, Object>) ((List<Object>) choicesObj).get(0);
        Object messageObj = firstChoice.get('message');
        if (!(messageObj instanceof Map<String, Object>)) {
            return null;
        }
        Object contentObj = ((Map<String, Object>) messageObj).get('content');
        return contentObj == null ? null : String.valueOf(contentObj);
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
