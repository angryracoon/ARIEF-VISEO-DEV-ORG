/**
 * @class        ReceiptExtractionResult
 * @description  DTO returned by ReceiptAiService implementations describing the
 *               values extracted from a scanned receipt image. All properties are
 *               @AuraEnabled so the structure can be returned directly to LWC.
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
public class ReceiptExtractionResult {

    /** Whether extraction completed successfully. */
    @AuraEnabled public Boolean success { get; set; }

    /** Human-readable error message when success is false. */
    @AuraEnabled public String errorMessage { get; set; }

    /** Merchant / store name read from the receipt. */
    @AuraEnabled public String merchantName { get; set; }

    /** Transaction date read from the receipt. */
    @AuraEnabled public Date expenseDate { get; set; }

    /** Total amount read from the receipt. */
    @AuraEnabled public Decimal totalAmount { get; set; }

    /** Suggested Category name to match against existing Category__c records. */
    @AuraEnabled public String suggestedCategoryName { get; set; }

    /** Model confidence score between 0 and 1. */
    @AuraEnabled public Decimal confidenceScore { get; set; }

    /**
     * @description  Default constructor. Initializes to an unsuccessful result so
     *               callers must explicitly mark success.
     */
    public ReceiptExtractionResult() {
        this.success = false;
    }

    /**
     * @description  Builds a failed result with an error message.
     * @param        message  Error description surfaced to the UI.
     * @return       A ReceiptExtractionResult flagged as unsuccessful.
     */
    public static ReceiptExtractionResult failure(String message) {
        ReceiptExtractionResult result = new ReceiptExtractionResult();
        result.success = false;
        result.errorMessage = message;
        return result;
    }
}
