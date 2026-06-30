/**
 * @class        GeminiReceiptAiProviderTest
 * @description  Tests for GeminiReceiptAiProvider using a simulated HTTP callout.
 *               Covers successful parse, code-fence wrapped JSON, unparseable
 *               content, non-2xx responses, empty candidates, and blank-input
 *               short-circuiting. Also asserts the factory's production default is
 *               now the Gemini provider. The provider is instantiated directly to
 *               bypass the factory's test-context mock.
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
@isTest
private class GeminiReceiptAiProviderTest {

    /** Configurable HttpCalloutMock returning a fixed status and body. */
    private class GeminiMock implements HttpCalloutMock {
        private Integer statusCode;
        private String body;

        GeminiMock(Integer statusCode, String body) {
            this.statusCode = statusCode;
            this.body = body;
        }

        public HTTPResponse respond(HTTPRequest request) {
            HttpResponse response = new HttpResponse();
            response.setHeader('Content-Type', 'application/json');
            response.setStatusCode(this.statusCode);
            response.setStatus(this.statusCode == 200 ? 'OK' : 'Error');
            response.setBody(this.body);
            return response;
        }
    }

    /**
     * @description  Wraps a model text string in a minimal Gemini generateContent
     *               response envelope.
     * @param        innerText  The model part text.
     * @return       A JSON string matching the Gemini response shape.
     */
    private static String geminiBody(String innerText) {
        return '{"candidates":[{"content":{"parts":[{"text":' +
            JSON.serialize(innerText) + '}]}}]}';
    }

    @isTest
    static void parsesSuccessfulResponse() {
        String innerJson = '{"merchantName":"Corner Cafe","expenseDate":"2026-06-15",' +
            '"totalAmount":12.30,"suggestedCategory":"Dining","confidenceScore":0.88}';
        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, geminiBody(innerJson)));

        Test.startTest();
        ReceiptExtractionResult result = new GeminiReceiptAiProvider()
            .extractFromReceipt('Zm9v', 'image/jpeg');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Provider should report success.');
        System.assertEquals('Corner Cafe', result.merchantName, 'Merchant parsed.');
        System.assertEquals(Date.newInstance(2026, 6, 15), result.expenseDate, 'Date parsed.');
        System.assertEquals(12.30, result.totalAmount, 'Amount parsed.');
        System.assertEquals('Dining', result.suggestedCategoryName, 'Category parsed.');
        System.assertEquals(0.88, result.confidenceScore, 'Confidence parsed.');
    }

    @isTest
    static void parsesCodeFenceWrappedJson() {
        String innerJson = '```json\n{"merchantName":"Fenced","totalAmount":5}\n```';
        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, geminiBody(innerJson)));

        Test.startTest();
        ReceiptExtractionResult result = new GeminiReceiptAiProvider()
            .extractFromReceipt('Zm9v', 'image/png');
        Test.stopTest();

        System.assertEquals(true, result.success, 'Fenced JSON should still parse.');
        System.assertEquals('Fenced', result.merchantName, 'Merchant parsed from fenced JSON.');
    }

    @isTest
    static void unparseableContentReturnsFailure() {
        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, geminiBody('this is not json')));

        Test.startTest();
        ReceiptExtractionResult result = new GeminiReceiptAiProvider()
            .extractFromReceipt('Zm9v', 'image/jpeg');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Unparseable content should fail gracefully.');
        System.assertNotEquals(null, result.errorMessage, 'An error message should be present.');
    }

    @isTest
    static void nonSuccessStatusReturnsFailure() {
        Test.setMock(HttpCalloutMock.class, new GeminiMock(500, '{"error":"server"}'));

        Test.startTest();
        ReceiptExtractionResult result = new GeminiReceiptAiProvider()
            .extractFromReceipt('Zm9v', 'image/jpeg');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Non-2xx should fail.');
        System.assertNotEquals(null, result.errorMessage, 'An error message should be present.');
    }

    @isTest
    static void emptyCandidatesArrayReturnsFailure() {
        Test.setMock(HttpCalloutMock.class, new GeminiMock(200, '{"candidates":[]}'));

        Test.startTest();
        ReceiptExtractionResult result = new GeminiReceiptAiProvider()
            .extractFromReceipt('Zm9v', 'image/jpeg');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Empty candidates should fail.');
    }

    @isTest
    static void blankImageShortCircuits() {
        Test.startTest();
        ReceiptExtractionResult result = new GeminiReceiptAiProvider()
            .extractFromReceipt('', 'image/jpeg');
        Test.stopTest();

        System.assertEquals(false, result.success, 'Blank image should fail without a callout.');
    }

    @isTest
    static void factoryDefaultProviderIsGemini() {
        System.assert(
            ReceiptAiServiceFactory.createDefaultProvider() instanceof GeminiReceiptAiProvider,
            'The production default provider should be the Gemini provider.'
        );
    }
}
