# The 7 Deadly Agents — App, Layout, and Permission Set Group

**Date:** 2026-06-18
**Status:** Completed
**Branch:** feature/2026-06-18-the-7-deadly-agents-app

---

## Overview

**Original request:** Create a custom Lightning app called "The 7 Deadly Agents" assigned to the System Administrator profile with tabs for Account and Project Task. Create a meaningful page layout for Project_Task__c showing key fields in logical groupings. Create a Permission Set Group called DefaultAdmin_PSG combining the existing ProjectTask_RW_PS and ProjectTask_DELETE_PS permission sets.

**Summary:** This feature is fully declarative — no Apex, LWC, or Flow was written. It adds the UI layer on top of the Project_Task__c object that was created in prior sprints: a navigation tab, a structured page layout, a Lightning app that surfaces both Account and Project Task in one experience, and a convenience Permission Set Group for administrators who need full read-write-delete access to Project Tasks.

---

## Components created

### Admin (declarative)

| Type | API Name | File | Description |
|------|----------|------|-------------|
| Custom Tab | `Project_Task__c` | `tabs/Project_Task__c.tab-meta.xml` | Navigation tab for Project_Task__c using motif Custom58 (Handsaw) |
| Lightning App | `The_7_Deadly_Agents` | `applications/The_7_Deadly_Agents.app-meta.xml` | Lightning Standard nav app with Account and Project Task tabs |
| Page Layout | `Project_Task__c-Project Task Layout` | `layouts/Project_Task__c-Project Task Layout.layout-meta.xml` | Three-section layout for Project_Task__c records |
| Permission Set Group | `DefaultAdmin_PSG` | `permissionsetgroups/DefaultAdmin_PSG.permissionsetgroup-meta.xml` | Groups ProjectTask_RW_PS + ProjectTask_DELETE_PS for admin assignment |

### Development (code)

None — this feature is fully declarative.

---

## Component detail

### Custom Tab — Project_Task__c

- **Motif:** Custom58: Handsaw (legacy Salesforce Classic icon)
- **Purpose:** Required for the Lightning App to include Project_Task__c in its tab bar. Without this tab, the app cannot reference the object in its navigation.

### Lightning App — The_7_Deadly_Agents

| Property | Value |
|----------|-------|
| Label | The 7 Deadly Agents |
| UI Type | Lightning |
| Nav Type | Standard |
| Form Factors | Large (desktop) |
| Default Landing Tab | standard-Account |
| Tab order | 1. Accounts, 2. Project Tasks |
| Workspace Type | Standard |

- **Nav personalization** and **auto temp tabs** are both enabled (defaults).
- App visibility for the System Administrator profile must be assigned manually after deployment — see Post-Deployment Steps below.

### Page Layout — Project Task Layout

Three sections, each using a two-column top-to-bottom style:

**Section 1: Task Information**

| Left column | Right column |
|-------------|--------------|
| Task_Name__c (Required) | Priority__c |
| Status__c | OwnerId |

**Section 2: Dates**

| Left column | Right column |
|-------------|--------------|
| Due_Date__c | Reminder_Date__c |
| Completed_Date__c | _(empty)_ |

**Section 3: System Information**

| Left column | Right column |
|-------------|--------------|
| CreatedById | LastModifiedById |

### Permission Set Group — DefaultAdmin_PSG

| Property | Value |
|----------|-------|
| Label | DefaultAdmin PSG |
| API Name | DefaultAdmin_PSG |
| Description | Default Admin Permission Set Group combining RW and DELETE access for Project Tasks |
| Member sets | ProjectTask_RW_PS, ProjectTask_DELETE_PS |

This PSG is a convenience grouping. It does not grant anything beyond what the two constituent permission sets already grant individually. Assign it to users who need full read, create, edit, and delete access to Project_Task__c records.

**Access summary when DefaultAdmin_PSG is assigned:**

| Permission | Source |
|------------|--------|
| Read | ProjectTask_RW_PS |
| Create | ProjectTask_RW_PS |
| Edit | ProjectTask_RW_PS |
| Delete | ProjectTask_DELETE_PS |

---

## Data flow

This feature does not introduce any new record processing logic. It is a UI and access configuration layer only.

1. A user is assigned `DefaultAdmin_PSG` — they receive full CRUD access on Project_Task__c.
2. The user opens the "The 7 Deadly Agents" Lightning app from the App Launcher.
3. The app loads with Accounts as the default landing tab; Project Tasks is the second tab.
4. When the user opens or creates a Project_Task__c record, the "Project Task Layout" is applied, presenting fields in the Task Information, Dates, and System Information sections.

---

## File locations

| Component | Path |
|-----------|------|
| Custom Tab | `force-app/main/default/tabs/Project_Task__c.tab-meta.xml` |
| Lightning App | `force-app/main/default/applications/The_7_Deadly_Agents.app-meta.xml` |
| Page Layout | `force-app/main/default/layouts/Project_Task__c-Project Task Layout.layout-meta.xml` |
| Permission Set Group | `force-app/main/default/permissionsetgroups/DefaultAdmin_PSG.permissionsetgroup-meta.xml` |

---

## Post-deployment steps (mandatory)

These steps must be performed manually in the org after deployment because Salesforce does not allow profile `applicationVisibilities` to be set via source-format metadata in all deployment modes.

### 1. Assign app visibility to System Administrator

1. Go to **Setup > App Manager**.
2. Find "The 7 Deadly Agents" in the list.
3. Click the dropdown arrow on the right and select **Edit**.
4. Under **Assign to Profiles**, add **System Administrator**.
5. Save.

Without this step, System Administrators will not see the app in the App Launcher.

### 2. Assign layout to the Project Task object

Salesforce deploys page layouts but does not automatically assign them to profiles unless a Profile metadata file includes the layout assignment. Verify the layout is assigned:

1. Go to **Setup > Object Manager > Project Task > Page Layouts**.
2. Click **Page Layout Assignment**.
3. Confirm "Project Task Layout" is assigned to the relevant profiles (at minimum: System Administrator).
4. If not assigned, click **Edit Assignment** and assign accordingly.

### 3. Assign DefaultAdmin_PSG to users

DefaultAdmin_PSG is deployed but not auto-assigned to any user.

1. Go to **Setup > Permission Set Groups**.
2. Open **DefaultAdmin PSG**.
3. Click **Manage Assignments** and add the relevant users.

---

## Security model

This feature is entirely declarative. No Apex sharing logic applies.

| Layer | Detail |
|-------|--------|
| Object access | Controlled by permission sets (ProjectTask_RW_PS, ProjectTask_DELETE_PS) |
| App visibility | Must be assigned to profiles via App Manager post-deploy |
| Layout visibility | Controlled by page layout assignment per profile |
| PSG | Groups existing permission sets; no new permissions introduced |

---

## Known limitations and code review warnings

These were flagged during code review (verdict: **APPROVED WITH WARNINGS**).

### 1. Classic tab motif (cosmetic)
- The tab uses `Custom58: Handsaw`, which is a legacy Salesforce Classic icon.
- In Lightning Experience, the icon renders but may not match the visual language of standard Lightning icons.
- **Impact:** Cosmetic only. Functionality is not affected.
- **Future suggestion:** Replace with a Lightning Design System (SLDS) utility icon by creating the tab through Setup UI in a future sprint.

### 2. App visibility requires manual post-deploy step
- The `applicationVisibilities` entry for System Administrator was not included in the deployed profile metadata due to source-format compatibility constraints.
- **Impact:** System Administrators will not see the app in the App Launcher until visibility is manually assigned via App Manager.
- **Action required:** See Post-Deployment Steps above.

### 3. Task_Name__c is layout-required only
- `Task_Name__c` is marked `behavior=Required` on the page layout, but the field itself is not defined as required at the object/field level.
- **Impact:** Salesforce UI will enforce the required behavior for users on this layout. However, API calls (REST, SOAP, Bulk) and programmatic DML (Apex) can insert or update records without a value in Task_Name__c.
- **Future suggestion:** If Task_Name__c should always be populated, add a field-level required constraint or a validation rule to enforce it outside the UI.

### 4. System Information fields use behavior=Edit
- `CreatedById` and `LastModifiedById` in the System Information section have `behavior=Edit` in the layout XML.
- **Impact:** Salesforce ignores edit behavior for system fields — they are always rendered as read-only regardless of layout behavior. This is harmless but semantically inconsistent.
- **Future suggestion:** Update to `behavior=Readonly` in a future layout revision for metadata accuracy.

---

## Dependencies

| Dependency | Type | Notes |
|------------|------|-------|
| Project_Task__c object | Custom object | Must exist before tab/layout/PSG can be deployed |
| ProjectTask_RW_PS | Permission set | Must exist before DefaultAdmin_PSG can reference it |
| ProjectTask_DELETE_PS | Permission set | Must exist before DefaultAdmin_PSG can reference it |
| All Project_Task__c fields | Custom fields | Must exist before the page layout references them |

All dependencies were verified present in the org at the time of development.

---

## Change history

| Date | Change |
|------|--------|
| 2026-06-18 | Initial creation — Custom Tab, Lightning App, Page Layout, Permission Set Group |
