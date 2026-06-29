import { createElement } from 'lwc';
import ReceiptScanWorkflow from 'c/receiptScanWorkflow';

// Auto-mocked Apex imports return resolved promises by default.
jest.mock(
    '@salesforce/apex/ReceiptScanController.getActiveFinancialAccounts',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

describe('c-receipt-scan-workflow', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it('renders the capture step first', () => {
        const element = createElement('c-receipt-scan-workflow', { is: ReceiptScanWorkflow });
        document.body.appendChild(element);

        const heading = element.shadowRoot.querySelector('h2');
        expect(heading.textContent).toContain('Capture Receipt');

        const fileInput = element.shadowRoot.querySelector('lightning-input');
        expect(fileInput).not.toBeNull();
    });

    it('dispatches a close event when cancel is clicked', () => {
        const element = createElement('c-receipt-scan-workflow', { is: ReceiptScanWorkflow });
        document.body.appendChild(element);

        const handler = jest.fn();
        element.addEventListener('close', handler);

        const cancel = Array.from(
            element.shadowRoot.querySelectorAll('lightning-button')
        ).find((b) => b.label === 'Cancel');
        cancel.click();

        expect(handler).toHaveBeenCalled();
    });
});
