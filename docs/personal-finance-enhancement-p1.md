# Enhancement Sprint 2 - Financial Account Management & AI Receipt Scanner

# Background

This enhancement is being implemented against an **existing Salesforce Personal Finance application**.

**Important:** The Git repository provided for this task is currently empty and does **not** contain the existing metadata. The implementation team is expected to retrieve the metadata from the connected Salesforce org before beginning development.

Do **not** assume this is a greenfield project.

The goal is to understand the existing application, extend it, and reuse its architecture and business logic whenever possible.

---

# Existing Application

The Salesforce org already contains a working Personal Finance application.

At minimum, the following components already exist:

## Lightning App

* Personal Finance App

## Lightning Pages

* Personal Finance Home

## Custom Objects

* Expense__c
* Category__c
* Budget__c

## Existing Functionality

The existing application already supports:

* Manual Expense creation
* Expense Category management
* Budget management
* Existing validation rules
* Existing automation
* Existing reports and dashboards

The implementation team should retrieve the metadata and understand how the current solution is designed before implementing new functionality.

Do not recreate objects, fields, pages, or business logic that already exist.

---

# Enhancement Scope

This sprint introduces two new capabilities:

1. Financial Account Management
2. AI-powered Receipt Scanner

The enhancement should integrate naturally into the existing application.

---

# Feature 1 - Financial Account Management

## Objective

Allow users to manage the payment sources used for their expenses.

Examples include:

* Cash
* DBS Savings
* OCBC Savings
* UOB One
* Citi Rewards
* Trust Bank
* GrabPay
* YouTrip

## Requirements

Create a new custom object:

**FinancialAccount__c**

Minimum fields:

* Account Name
* Account Type
* Currency
* Current Balance
* Status
* Notes

Update **Expense__c** to include a lookup relationship to **FinancialAccount__c**.

Whenever an Expense is:

* Created
* Updated
* Deleted

the associated Financial Account balance should be updated automatically.

Inactive Financial Accounts must not be selectable when creating or editing an Expense.

---

# Feature 2 - AI Receipt Scanner

## Objective

Reduce manual data entry by allowing users to create an Expense from a receipt.

---

## Personal Finance Home

Enhance the existing **Personal Finance Home** page.

Add a Lightning Web Component named **Expense Creation Panel**.

This component should become the primary entry point for creating new Expenses.

The panel should present two options:

### Create Expense Manually

Open the standard Salesforce New Expense page.

Continue using the existing Expense creation process.

### Scan Receipt

Launch a guided receipt scanning workflow.

The workflow should:

1. Capture a receipt using the device camera or upload an existing image.
2. Upload the image as a Salesforce File (ContentVersion).
3. Send the receipt to an AI/OCR service.
4. Extract receipt information.
5. Display a review screen.
6. Allow users to edit extracted values.
7. Require the user to select a Financial Account.
8. Create the Expense after confirmation.
9. Attach the receipt to the Expense record.

---

## AI Extraction

The AI should attempt to extract:

* Merchant Name
* Expense Date
* Total Amount
* Currency
* Suggested Category
* Confidence Score

The AI integration should be implemented behind a reusable service layer so different providers can be supported in the future.

---

## Category Matching

The application already contains **Category__c** records.

The AI must never create new Categories.

Instead:

* Search existing Category records.
* Automatically populate the Category lookup when a suitable match exists.
* If no suitable match exists, require the user to choose the correct Category manually.

---

## Existing Business Logic

The Receipt Scanner must extend the existing application.

Do **not** duplicate existing business logic.

Instead, reuse the same Expense creation process already used by manual Expense creation.

Existing functionality should continue to work, including:

* Budget calculations
* Validation rules
* Existing automation
* Existing reporting

The enhancement should integrate with the current architecture rather than replacing it.

---

## Error Handling

If receipt processing fails:

* Keep the uploaded receipt.
* Display an appropriate error message.
* Allow the user to manually complete the Expense without uploading the receipt again.

---

# Technical Requirements

Before implementation:

* Retrieve the existing metadata from the connected Salesforce org.
* Analyze the current application structure.
* Reuse existing components and services whenever appropriate.

Implementation should follow Salesforce best practices, including:

* Lightning Web Components
* Apex Service Layer
* Bulk-safe Apex
* Reusable AI integration
* Proper exception handling
* Unit tests

---

# Acceptance Criteria

The enhancement is complete when:

* Existing metadata has been retrieved from the Salesforce org.
* FinancialAccount__c has been implemented.
* Expense__c references FinancialAccount__c.
* Users can create Expenses manually from the Personal Finance Home page.
* Users can create Expenses by scanning a receipt.
* AI extracts receipt information for review.
* Existing Category__c records are reused.
* Users confirm extracted information before the Expense is created.
* Receipts are attached to the Expense.
* Existing Expense__c, Category__c, and Budget__c functionality continues to work without regression.
