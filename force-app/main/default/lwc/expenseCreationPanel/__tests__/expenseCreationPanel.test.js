import { createElement } from 'lwc';
import ExpenseCreationPanel from 'c/expenseCreationPanel';

describe('c-expense-creation-panel', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    function flushPromises() {
        return Promise.resolve();
    }

    it('renders the two action buttons by default', () => {
        const element = createElement('c-expense-creation-panel', { is: ExpenseCreationPanel });
        document.body.appendChild(element);

        const buttons = element.shadowRoot.querySelectorAll('lightning-button');
        const labels = Array.from(buttons).map((b) => b.label);
        expect(labels).toContain('Create Manually');
        expect(labels).toContain('Scan Receipt');
    });

    it('reveals the receipt scan workflow when Scan Receipt is clicked', async () => {
        const element = createElement('c-expense-creation-panel', { is: ExpenseCreationPanel });
        document.body.appendChild(element);

        const scanButton = Array.from(
            element.shadowRoot.querySelectorAll('lightning-button')
        ).find((b) => b.label === 'Scan Receipt');
        scanButton.click();

        await flushPromises();

        const workflow = element.shadowRoot.querySelector('c-receipt-scan-workflow');
        expect(workflow).not.toBeNull();
    });
});
