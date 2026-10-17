# COMMON user guide videos

One short video per COMMON component (release 89), recorded in the COMMON application as IT (Common Administrator).
Each video opens with what the component is for, walks through its screens with the help text of each page as
captions, and ends with how another application uses it. The videos have no sound; the captions carry the guide.

Re-record after a release: `python3 apex/tools/record_user_guide.py` (needs a COMMON database with sample data).

| Module | Component | Video | Length | What it is for |
| --- | --- | --- | --- | --- |
| Platform | Application Settings | [app-settings.mp4](videos/app-settings.mp4) | 00:34 | Application settings. |
| Platform | Applications | [applications.mp4](videos/applications.mp4) | 01:26 | Registered applications, the common functions switched on for each, their setup. |
| Platform | Common Home | [home.mp4](videos/home.mp4) | 00:32 | The landing page of the COMMON application. |
| Platform | Data Model | [data-model.mp4](videos/data-model.mp4) | 01:23 | The database objects of every registered application, read live from the database dictionary: the object catalogue and the entity-relationship diagram (release 89). |
| Platform | Give Feedback | [give-feedback.mp4](videos/give-feedback.mp4) | 00:34 | Everyone gives feedback on the page they are on, in any application. |
| Platform | Optional Features | [optional-features.mp4](videos/optional-features.mp4) | 00:23 | Optional features of each application, switched on or off. |
| Platform | Platform Activity | [platform-activity.mp4](videos/platform-activity.mp4) | 00:28 | Page views, top users, errors and page performance of every registered application (APEX activity log). |
| Platform | Usage and Feedback | [usage-feedback.mp4](videos/usage-feedback.mp4) | 00:37 | The feedback people gave on every registered application, and its follow-up. |
| Security | Audit Log | [audit-log.mp4](videos/audit-log.mp4) | 00:24 | Who changed what and when. |
| Security | Data Security | [data-security.mp4](videos/data-security.mp4) | 00:48 | Data access rules: which rows each user and role can see. |
| Security | Roles & Privileges | [roles-privileges.mp4](videos/roles-privileges.mp4) | 00:55 | Roles, the privileges they grant and segregation of duties. |
| Security | Users & Access | [users-access.mp4](videos/users-access.mp4) | 00:58 | Users, their roles and their data access. |
| Reference Data | Flexfields | [flexfields.mp4](videos/flexfields.mp4) | 01:04 | Descriptive flexfields and their value sets. |
| Reference Data | Lookups | [lookups.mp4](videos/lookups.mp4) | 00:43 | Lists of values used across the application. |
| Documents and Records | Attachments | [attachments.mp4](videos/attachments.mp4) | 01:01 | Document categories, storage and where attachments appear. |
| Documents and Records | Documents | [documents.mp4](videos/documents.mp4) | 00:56 | The documents of a record of any application: add, view, replace (the application's attachment page registration says who may change them). |
| Documents and Records | Retention | [retention.mp4](videos/retention.mp4) | 00:35 | How long records and documents are kept. |
| Workflow | Approval Setup | [approval-setup.mp4](videos/approval-setup.mp4) | 00:54 | Approval rules: who approves which record, step by step. |
| Workflow | Communications | [communications.mp4](videos/communications.mp4) | 00:52 | The e-mails with outside people of a record of any application: send, record a received one, history. |
| Workflow | Configuration Change Approvals | [change-approvals.mp4](videos/change-approvals.mp4) | 00:38 | Who approves the configuration changes of every application (maker-checker, process CONFIG_CHANGE). |
| Workflow | Information Requests (RFI) | [information-requests.mp4](videos/information-requests.mp4) | 00:40 | Asking someone (a colleague or an outside person) for information on a record, with the answer loop (RFI workflow). |
| Workflow | My Tasks | [my-tasks.mp4](videos/my-tasks.mp4) | 00:57 | The tasks of the signed-in user from every application. |
| Workflow | Notifications | [notifications.mp4](videos/notifications.mp4) | 01:21 | E-mail and in-app notification templates. |
| Workflow | Workflow Monitor | [workflow-monitor.mp4](videos/workflow-monitor.mp4) | 00:33 | Running workflows and tasks of every application: act on anyone's behalf. |
| Workflow | Workflow Setup | [workflow-setup.mp4](videos/workflow-setup.mp4) | 00:59 | Delegations, deadlines and escalation, process catalogue. |
| Integrations | Integrations | [integrations.mp4](videos/integrations.mp4) | 01:04 | Endpoints, purposes and the transmission log. |

For developers of other applications: read `COMMON-GUIDE.md` next to this file (the same text as the shared COMMON Application Guide).
