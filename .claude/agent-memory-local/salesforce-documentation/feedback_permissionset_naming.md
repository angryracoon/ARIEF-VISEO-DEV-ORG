---
name: feedback_permissionset_naming
description: Permission set API name convention — ObjectName (no __c) + access level + _PS
metadata:
  type: feedback
---

Permission set API names must follow: `[ObjectName]_[AccessLevel]_PS`

- ObjectName = Salesforce object name **without** the `__c` suffix and **without** underscores between words (camelCase run-together, e.g. `ProjectTask` not `Project_Task`)
- AccessLevel = RO, RW, or DELETE
- Examples: `ProjectTask_RO_PS`, `ProjectTask_RW_PS`, `ProjectTask_DELETE_PS`

**Why:** User corrected wrong naming (`Project_Task__c_RO_PS`) in a PR comment on 2026-06-17. The `__c` suffix and internal underscores from the object API name are dropped in permission set names.

**How to apply:** When documenting or reviewing permission sets for any custom object, always strip `__c` and collapse the object name to PascalCase before appending `_AccessLevel_PS`. Apply to both the filename and the `<fullName>` value inside the XML.
