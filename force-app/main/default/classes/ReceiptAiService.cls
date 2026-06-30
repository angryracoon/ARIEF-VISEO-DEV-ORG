/**
 * @interface    ReceiptAiService
 * @description  Provider-swappable contract for extracting structured expense data
 *               from a receipt image. Implementations include MockReceiptAiProvider
 *               (deterministic, used in tests and dev) and GeminiReceiptAiProvider
 *               (real Gemini Vision callout). Resolve an instance through
 *               ReceiptAiServiceFactory rather than constructing directly.
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
public interface ReceiptAiService {

    /**
     * @description  Extracts expense fields from a base64-encoded receipt image.
     * @param        base64Image  Base64-encoded image bytes.
     * @param        contentType  MIME type of the image (e.g. image/jpeg).
     * @return       A populated ReceiptExtractionResult.
     */
    ReceiptExtractionResult extractFromReceipt(String base64Image, String contentType);
}
