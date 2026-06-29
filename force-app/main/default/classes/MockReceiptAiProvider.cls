/**
 * @class        MockReceiptAiProvider
 * @description  Deterministic ReceiptAiService implementation that returns a fixed,
 *               realistic extraction result without any callout. Used automatically
 *               in test context (via ReceiptAiServiceFactory) and available for
 *               local development before the Claude provider is configured.
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
public with sharing class MockReceiptAiProvider implements ReceiptAiService {

    /**
     * @description  Returns a hardcoded successful extraction result. The input is
     *               not inspected; the same realistic sample is always returned.
     * @param        base64Image  Ignored.
     * @param        contentType  Ignored.
     * @return       A successful ReceiptExtractionResult with sample values.
     */
    public ReceiptExtractionResult extractFromReceipt(String base64Image, String contentType) {
        ReceiptExtractionResult result = new ReceiptExtractionResult();
        result.success = true;
        result.merchantName = 'FairPrice Finest';
        result.expenseDate = Date.today();
        result.totalAmount = 42.50;
        result.suggestedCategoryName = 'Groceries';
        result.confidenceScore = 0.92;
        return result;
    }
}
