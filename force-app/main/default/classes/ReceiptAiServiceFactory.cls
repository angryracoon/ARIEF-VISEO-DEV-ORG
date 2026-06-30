/**
 * @class        ReceiptAiServiceFactory
 * @description  Resolves the active ReceiptAiService implementation. Returns the
 *               deterministic MockReceiptAiProvider in test context and the real
 *               GeminiReceiptAiProvider otherwise, keeping callers decoupled from
 *               the concrete provider.
 * @author       Arief Gunawan
 * @date         2026-06-30
 */
public with sharing class ReceiptAiServiceFactory {

    /** Optional override used by tests to inject a specific provider. */
    @TestVisible
    private static ReceiptAiService overrideInstance;

    /**
     * @description  Returns the ReceiptAiService implementation to use. A test
     *               override takes precedence; otherwise the mock provider is used
     *               in test context and the Gemini provider in all other contexts.
     * @return       A ReceiptAiService instance.
     */
    public static ReceiptAiService getInstance() {
        if (overrideInstance != null) {
            return overrideInstance;
        }
        if (Test.isRunningTest()) {
            return new MockReceiptAiProvider();
        }
        return createDefaultProvider();
    }

    /**
     * @description  Constructs the production provider. Isolated into its own
     *               @TestVisible method so the real provider wiring can be exercised
     *               by tests without forcing a live callout through getInstance().
     * @return       The production ReceiptAiService (Gemini).
     */
    @TestVisible
    private static ReceiptAiService createDefaultProvider() {
        return new GeminiReceiptAiProvider();
    }
}
