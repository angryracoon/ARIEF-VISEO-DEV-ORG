---
name: feedback-flow-naming-convention
description: Mandatory Flow naming conventions for record-triggered and sub-flows in this org
metadata:
  type: feedback
---

Always follow these API name and label conventions for Flows:

**Record-triggered (After Save):**
- API name: `[ObjectName without __c]_After_Save`
- Label: `[ObjectName without __c, underscores replaced with spaces] After Save`
- Example: `Project_Task_After_Save` → `Project Task After Save`

**Sub-flow (Autolaunched):**
- API name: `[ObjectName without __c]_[Process_Name]_Subflow`
- Label: `[ObjectName without __c, spaces] [Process Name] - Subflow`
- Example: `Project_Task_Reminder_Notification_Subflow` → `Project Task Reminder Notification - Subflow`

**Why:** Org convention established by the design agent and enforced by the user. Consistent naming makes flows discoverable and identifies their type and scope at a glance.

**How to apply:** Any time a Flow metadata file is created — check the type first, then apply the correct naming pattern before writing the file.
