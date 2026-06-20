# Components Created — Sprint 1 Project Delivery Management

**Branch:** `feature/2026-06-19-project-delivery-management-sprint1`
**Date:** 2026-06-20
**Agent:** salesforce-admin

---

## Opportunity (Standard Object) — 13 Custom Fields

| # | API Name | Type |
|---|----------|------|
| 1 | `Project_Scope__c` | LongTextArea |
| 2 | `Project_Description__c` | LongTextArea |
| 3 | `Start_Date__c` | Date |
| 4 | `Planned_Go_Live_Date__c` | Date |
| 5 | `Actual_Go_Live_Date__c` | Date |
| 6 | `Planned_Mandays__c` | Number |
| 7 | `Actual_Mandays__c` | Number |
| 8 | `Project_Health__c` | Picklist |
| 9 | `Delivery_Methodology__c` | Picklist |
| 10 | `Current_Stage_Sign_Off_Complete__c` | Checkbox |
| 11 | `Total_Sprints__c` | Roll-Up Summary (COUNT from Project_Sprint__c) |
| 12 | `Total_Planned_Mandays__c` | Roll-Up Summary (SUM from Project_Sprint__c) |
| 13 | `Total_Actual_Mandays__c` | Roll-Up Summary (SUM from Project_Sprint__c) |

## Opportunity Object Metadata

| # | Component | Notes |
|---|-----------|-------|
| 14 | `Opportunity.object-meta.xml` | StageName picklist values (9 project stages + standard values) |
| 15 | Record Type: `VISEO_Project_Opportunity` | Active, 9 stage values |
| 16 | Path: `VISEO_Project_Opportunity_Path` | 9 stages, linked to VISEO_Project_Opportunity RT |
| 17 | Validation Rule: `Sign_Off_Required_Before_Stage_Advance` | Blocks stage advance without sign-off |

## OpportunityTeamMember — 1 Custom Field

| # | API Name | Type |
|---|----------|------|
| 18 | `Delivery_Role__c` | Picklist (12 values) |

## Project_Sign_Off__c — New Object + 5 Fields

| # | Component | Notes |
|---|-----------|-------|
| 19 | Object: `Project_Sign_Off__c` | AutoNumber PSO-{0000}, sharingModel=ControlledByParent |
| 20 | Field: `Opportunity__c` | Master-Detail (Opportunity) |
| 21 | Field: `Stage__c` | Picklist (4 values) |
| 22 | Field: `Sign_Off_Status__c` | Picklist (Pending default) |
| 23 | Field: `Approved_By__c` | Lookup (User) |
| 24 | Field: `Approval_Date__c` | Date |

## Project_Sprint__c — New Object + 14 Fields

| # | Component | Notes |
|---|-----------|-------|
| 25 | Object: `Project_Sprint__c` | Text name "Sprint Name", sharingModel=ControlledByParent |
| 26 | Field: `Opportunity__c` | Master-Detail (Opportunity) |
| 27 | Field: `Sprint_Number__c` | Number |
| 28 | Field: `Sprint_Goal__c` | Text |
| 29 | Field: `Sprint_Description__c` | LongTextArea |
| 30 | Field: `Sprint_Start_Date__c` | Date |
| 31 | Field: `Sprint_End_Date__c` | Date |
| 32 | Field: `Planned_Mandays__c` | Number |
| 33 | Field: `Actual_Mandays__c` | Number |
| 34 | Field: `Sprint_Status__c` | Picklist (Planning default) |
| 35 | Field: `Total_Activities__c` | Roll-Up Summary (COUNT all) |
| 36 | Field: `Total_Completed_Activities__c` | Roll-Up Summary (COUNT where Completed) |
| 37 | Field: `Total_Open_Activities__c` | Roll-Up Summary (COUNT not Completed AND not Cancelled) |
| 38 | Field: `Total_Estimated_Mandays__c` | Roll-Up Summary (SUM Estimated_Mandays__c) |
| 39 | Field: `Total_Actual_Mandays__c` | Roll-Up Summary (SUM Actual_Mandays__c) |

## Project_Activity__c — New Object + 10 Fields

| # | Component | Notes |
|---|-----------|-------|
| 40 | Object: `Project_Activity__c` | AutoNumber ACT-{00000}, enableFeeds=true, sharingModel=ControlledByParent |
| 41 | Field: `Project_Sprint__c` | Master-Detail (Project_Sprint__c) |
| 42 | Field: `Activity_Type__c` | Picklist (6 values) |
| 43 | Field: `Activity_Status__c` | Picklist (Not Started default) |
| 44 | Field: `Assigned_To__c` | Lookup (User) |
| 45 | Field: `Reviewer__c` | Lookup (User) |
| 46 | Field: `Estimated_Mandays__c` | Number |
| 47 | Field: `Actual_Mandays__c` | Number |
| 48 | Field: `Planned_Completion_Date__c` | Date |
| 49 | Field: `Actual_Completion_Date__c` | Date |
| 50 | Field: `Activity_Updates__c` | LongTextArea |

## Flows — 3

| # | API Name | Type |
|---|----------|------|
| 51 | `Opportunity_Before_Save` | Record-Triggered Before Save |
| 52 | `Opportunity_After_Save` | Record-Triggered After Save |
| 53 | `Project_Sign_Off_Upload_Document` | Screen Flow |

## Permission Sets — 2

| # | API Name | Access |
|---|----------|--------|
| 54 | `ProjectManagement_RW_PS` | Read/Create/Edit on 5 objects + all custom field permissions |
| 55 | `ProjectManagement_DELETE_PS` | Read/Delete on 5 objects |

## Permission Set Group — Updated

| # | Component | Change |
|---|-----------|--------|
| 56 | `DefaultAdmin_PSG` | Added ProjectManagement_RW_PS and ProjectManagement_DELETE_PS (kept existing members) |

## Custom Tabs — 3

| # | API Name |
|---|----------|
| 57 | `Project_Sprint__c` |
| 58 | `Project_Activity__c` |
| 59 | `Project_Sign_Off__c` |

## Lightning App — Updated

| # | Component | Change |
|---|-----------|--------|
| 60 | `The_7_Deadly_Agents` | Added 4 tabs: standard-Opportunity, Project_Sprint__c, Project_Activity__c, Project_Sign_Off__c |

## Lightning Record Pages — 4

| # | API Name | Object |
|---|----------|--------|
| 61 | `Opportunity_Project_Record_Page` | Opportunity |
| 62 | `Project_Sprint_Record_Page` | Project_Sprint__c |
| 63 | `Project_Activity_Record_Page` | Project_Activity__c |
| 64 | `Project_Sign_Off_Record_Page` | Project_Sign_Off__c |

---

**Total Components: 64**
