# Version 1 — Technical Specification
# Current JSF/Hibernate KYC System

**Document Type:** Technical Specification  
**Audience:** Developers, IT Team, System Administrators  
**Platform:** Java EE / JSF 2.2 / Hibernate 3.0 / MS SQL Server  
**Status:** Live Production — No Source Code Available  

---

## 1. System Architecture

### 1.1 Technology Stack

| Layer | Technology | Version |
|---|---|---|
| Web Framework | JavaServer Faces (JSF) | 2.2 |
| View Technology | Facelets (XHTML templates) | — |
| UI Components | PrimeFaces | — |
| ORM | Hibernate | 3.0 |
| Database | Microsoft SQL Server | — |
| CSS Framework | Bootstrap (QDbootstrap.css — custom) | Custom |
| Icons | Font Awesome | — |
| JavaScript | jQuery | — |
| Application Server | JBoss / Tomcat | Java EE 3.0 compatible |
| Email | SMTP (relay.qataridiar.com:25) | — |
| PDF Generation | iText / PDFRenderer | — |

### 1.2 Deployment

```
Application Server: JBoss / Tomcat
  └── /KycReport.war
        ├── WEB-INF/
        │     ├── web.xml              (servlet config, session timeout: 30 min)
        │     ├── faces-config.xml     (JSF navigation, managed bean registry)
        │     ├── jboss-web.xml        (JBoss container config)
        │     └── classes/
        │           ├── hibernate.cfg.xml
        │           ├── KycConfig.properties
        │           └── com/qd/          (compiled Java classes)
        └── *.xhtml, resources/, img/

Database: Microsoft SQL Server
  Host: QDHQSQL25\DB01
  Port: 53120
  Database: QDKYC
  Driver: com.microsoft.sqlserver.jdbc.SQLServerDriver

File Storage:
  Documents:  /u01/documents/support/
  Reports:    /u01/documents/reports/
```

### 1.3 Package Structure

```
com.qd/
├── pojo/          Entity classes (14) + Hibernate .hbm.xml mapping files
├── dao/           DatabaseOperations — single DAO class (all CRUD)
├── utlils/        Services: EmailUtil, HtmlEmailSender, SendEmail,
│                  HibernateUtils, ReportsUtils, ChartView,
│                  EntityConverter, EntityExtract, MenuView,
│                  PrintController (PDF), DocumentUtils
├── reports/       Report generation classes
└── entity/        Entity-specific business logic
```

---

## 2. Database Schema

### 2.1 Connection Configuration (hibernate.cfg.xml)

```xml
<property name="connection.url">
  jdbc:sqlserver://QDHQSQL25\DB01:53120;databaseName=QDKYC
</property>
<property name="connection.driver_class">
  com.microsoft.sqlserver.jdbc.SQLServerDriver
</property>
<property name="dialect">
  org.hibernate.dialect.SQLServerDialect
</property>
```

### 2.2 Full Table Definitions

#### Table: Kyc (Primary KYC Records)
| Column | Type | Nullable | Description |
|---|---|---|---|
| `qd_proc_ref_no` | VARCHAR | PK | Process reference number |
| `qd_business_counter_catg` | VARCHAR | | Business counterparty category |
| `qd_business_counter_type` | VARCHAR | | Legal Person / Natural Person |
| `qd_subject` | VARCHAR | | AdHoc KYC / Simplified KYC / Enhanced KYC |
| `qd_final_conclusion` | VARCHAR | | Conclusion text (free text) |
| `qd_req_date` | VARCHAR | | Request date (string — no validation) |
| `qd_count_designation` | VARCHAR | | Counterparty designation name |
| `qd_request_made_by` | VARCHAR | | Who requested the KYC |
| `qd_due_dig_type` | VARCHAR | | Due diligence type |
| `qd_due_dig_made_by` | VARCHAR | | Officer who performed DD |
| `qd_initial_req_msg` | VARCHAR | | Initial request message |
| `qd_kyc_report_status` | VARCHAR | FK | → KycReportStatusMaster |
| `qd_risk_level` | VARCHAR | | Low / Medium / High |
| `qd_seq_id` | INTEGER | | Sequence ID |
| `qd_kyc_wf_status` | VARCHAR | | Workflow status string |
| `qd_kyc_next_step` | VARCHAR | | Next steps text |
| `qd_is_draft` | VARCHAR | | Y / N |
| `qd_is_approve` | VARCHAR | | Y / N |
| `wf_level` | INTEGER | | 1 = L1, 2 = L2 |
| `qd_ent_ref` | INTEGER | FK | → EntityReference |
| `qd_last_actioned_date` | VARCHAR | | Last action date (string) |

#### Table: KycSP (Search Pattern / Entity)
| Column | Type | Nullable | Description |
|---|---|---|---|
| `qd_sp_id` | INTEGER | PK | Entity identifier |
| `qd_proc_ref_no` | VARCHAR | | Related KYC reference |
| `spName` | VARCHAR | | Entity name |
| `spCountryLoc` | VARCHAR | | Country location |
| `spResults` | VARCHAR | | Screening results (free text) |
| `spConclusion` | VARCHAR | | Conclusion (free text) |
| `qd_sp_head_quarters` | VARCHAR | | HQ address (free text) |
| `qd_active` | VARCHAR | | Y / N |
| `qd_sp_status` | VARCHAR | | Entity status |
| `qd_is_edit` | VARCHAR | | Edit flag |
| `qd_is_update` | VARCHAR | | Update flag |
| `qd_is_used` | VARCHAR | | Used flag |
| `qd_version` | INTEGER | | Version number |
| `qd_chronic_id` | INTEGER | | Groups all versions |
| `qd_version_no` | INTEGER | | Version sequence |
| `qd_sp_nature` | VARCHAR | | Natural Person / Legal Person |
| `qd_person_id` | VARCHAR | | ID / Passport number |
| `qd_legal_reg_no` | VARCHAR | | Company registration number |
| `qd_natural_person_dob` | VARCHAR | | DOB (string — no validation) |
| `qd_natural_person_nationality` | VARCHAR | | Nationality |
| `qd_risk_level` | VARCHAR | | Low / Medium / High |

#### Table: Ubo (Ultimate Beneficial Owners)
| Column | Type | Nullable | Description |
|---|---|---|---|
| `qd_ubo_id` | INTEGER | PK | UBO record ID |
| `qd_proc_ref_no` | VARCHAR | | Related KYC reference |
| `ubo_nationality` | VARCHAR | | Nationality |
| `ubo_dob` | VARCHAR | | Date of birth (string) |
| `ubo_idno` | VARCHAR | | ID / Passport number |
| `ubo_results` | VARCHAR | | Screening results (free text) |
| `ubo_oth_scn_proc` | VARCHAR | | Conclusion / other notes |
| `ubo_source` | VARCHAR | | Information source |
| `ubo_name` | VARCHAR | | UBO / signatory name |
| `ubo_type` | VARCHAR | | UBO / Authorized Signatories |
| `ubo_id_exp_date` | VARCHAR | | ID expiry (string) |

#### Table: Login (Users)
| Column | Type | Nullable | Description |
|---|---|---|---|
| `userId` | VARCHAR | PK | Login username |
| `userPass` | VARCHAR | NOT NULL | Password (**⚠ plain text — critical security issue**) |
| `first_name` | VARCHAR | | First name |
| `last_name` | VARCHAR | | Last name |
| `mobile` | VARCHAR | | Mobile number |
| `role` | VARCHAR | | Primary role |
| `role1` | VARCHAR | | Secondary role |
| `role2` | VARCHAR | | Tertiary role |
| `email_id` | VARCHAR | | Email address for notifications |

#### Table: KycDocuments
| Column | Type | Nullable | Description |
|---|---|---|---|
| `qd_doc_id` | INTEGER | PK | Document ID |
| `qd_proc_ref_id` | VARCHAR | FK | → Kyc.qd_proc_ref_no |
| `qd_doc_name` | VARCHAR | | File name |
| `qd_doc_date` | VARCHAR | | Upload date (string) |
| `qd_doc_path` | VARCHAR | | File system path |

#### Table: ProcessLog (Immutable Audit Trail)
| Column | Type | Nullable | Description |
|---|---|---|---|
| `qd_kyc_log_id` | INTEGER | PK | Log entry ID |
| `qd_proc_ref_no` | VARCHAR | FK | → Kyc.qd_proc_ref_no |
| `kyc_wf_status` | VARCHAR | | Status at time of action |
| `log_user` | VARCHAR | | User who acted |
| `kyc_comments` | VARCHAR | | Free-text notes |
| `log_date` | VARCHAR | | Timestamp (string) |

#### Table: KycWfComments
| Column | Type | Nullable | Description |
|---|---|---|---|
| `qd_comm_id` | INTEGER | PK | Comment ID |
| `qd_proc_ref_no` | VARCHAR | FK | → Kyc |
| `qd_comments` | VARCHAR | | Comment text |
| `qd_comm_user` | VARCHAR | | User who commented |
| `qd_comm_date` | VARCHAR | | Comment date (string) |
| `qd_comm_wf_status` | VARCHAR | | Workflow status at time |

#### Remaining Tables (Reference Data)
| Table | PK | Key Columns |
|---|---|---|
| `KycReportStatusMaster` | reportStatusID | qd_kyc_report_status, report_color |
| `KycResults` | qd_result_id | qd_results, result_color |
| `KycRequestBy` | qd_req_by_id | qd_req_by_name |
| `Business_Counterparty_Category` | qd_bcp_id | qd_bcp_name |
| `EntityReference` | qd_er_id | qd_proc_ref_no, qd_sp_id |
| `SPReference` | qd_sp_id | er_ref_no, er_rel_ref_no |
| `Countries` | country_name | country_region |

---

## 3. Managed Beans (Controllers)

| Bean Name | Scope | Responsibilities |
|---|---|---|
| `Login` | Session | Authentication, session state, role routing |
| `Kyc` | Request | KYC create/edit/submit, document upload |
| `kyclist` | View | KYC search, list population, approval actions |
| `SearchPattern` | Request | Entity create/edit/search, UBO management |
| `MenuView` | Session | Role-based navigation menu rendering |
| `PrintController` | Request | PDF generation, watermark application |
| `ChartView` | View | Dashboard chart data |
| `ReportsUtils` | Request | Report query and data preparation |

---

## 4. Navigation (faces-config.xml Outcomes)

| From Page | Outcome String | Destination |
|---|---|---|
| login.xhtml | contributor | master.xhtml |
| login.xhtml | approver | apmaster.xhtml |
| login.xhtml | rfi | rfimaster.xhtml |
| login.xhtml | invalid | invalidPage.xhtml |
| landing.xhtml | saveKyc | output.xhtml |
| landing.xhtml | submitKyc | output.xhtml |
| apmaster.xhtml | kycApprove | apmaster.xhtml |
| apmaster.xhtml | kycReject | apmaster.xhtml |
| master.xhtml | editKyc | editKycMaster.xhtml |
| entity/* | saveEntity | master.xhtml |
| entity/* | uboData | entity/editUboMaster.xhtml |

---

## 5. Configuration Files

### KycConfig.properties
```properties
KYC_Support_File_Path=/u01/documents/support/
KYC_Report_File_Path=/u01/documents/reports/
KYC_Server_Address=http://qdhqkyc:8080
smtp_host=relay.qataridiar.com
smtp_port=25
smtp_sender_email=kycreport@qataridiar.com
smtp_sender_password=KxYrKe45UkM$
```
> **⚠ Security:** SMTP password stored in plain text. Rotate immediately and use encrypted credential storage.

### web.xml Key Settings
```xml
<session-config>
  <session-timeout>30</session-timeout>
</session-config>
<welcome-file-list>
  <welcome-file>login.xhtml</welcome-file>
</welcome-file-list>
```

---

## 6. XHTML Page Inventory (66 templates)

### Root Level (KYC Workflow)
| File | Purpose |
|---|---|
| login.xhtml | Authentication form |
| landing.xhtml | KYC creation form |
| index.xhtml / index_1.xhtml | KYC creation variants |
| master.xhtml | KYC search and list |
| search.xhtml | Advanced search |
| editKycMaster.xhtml / editKyc.xhtml | KYC edit |
| apmaster.xhtml | Level 1 approval queue |
| appsearch.xhtml | Approval search |
| rfimaster.xhtml | Level 2 / RFI queue |
| rfisearch.xhtml | RFI search |
| kyclist.xhtml | KYC list view |
| kycoutput.xhtml | Post-creation output |
| output.xhtml / outputPage.xhtml | Post-submit output |
| Print.xhtml | PDF print view |
| commonLayout.xhtml | Master page template |
| appCommonLayout.xhtml | Approver layout |
| rfiCommonLayout.xhtml | RFI/L2 layout |
| loginlayout.xhtml | Login layout |
| commonHeader.xhtml / commonFooter.xhtml | Shared header/footer |
| appCommonHeader.xhtml / rfiCommonHeader.xhtml | Role-specific headers |
| level2CommonHeader.xhtml | L2 header |
| usrcntl.xhtml | User control panel |

### /entity/ (16 files — Entity & UBO Management)
entityMaster, editEntityMaster, entityUpdateMaster, entitySearchMaster, entityVersionMaster, entityVersionSearchMaster, editUboMaster + supporting pages

### /BackOfficeMaster/ (8 files — Reference Data Admin)
KycReportStatusMaster, KycResultsMaster, KycRequestByMaster, Business_Counterparty_CategoryMaster

### /um/ (6 files — User Management)
userManagementMaster, userCreateMaster, userEditMaster

### /charts/ (2 files), /reports/ (2 files)

---

## 7. Known Technical Defects

| ID | Defect | Risk Level | Recommended Fix |
|---|---|---|---|
| TD-01 | Passwords stored in plain text in Login table | **Critical** | Implement BCrypt hashing immediately |
| TD-02 | SMTP password in plain text in properties file | **Critical** | Move to encrypted credential store |
| TD-03 | Date fields stored as VARCHAR — no type validation | High | Migrate to proper DATE type with constraints |
| TD-04 | No source code available for the application | **Critical** | Source code must be located or system rebuilt |
| TD-05 | Single DAO class handles all DB operations | Medium | Acceptable for current scale; refactor if extending |
| TD-06 | Hibernate 3.0 — end of life | Medium | Upgrade to Hibernate 5+ if extending |
| TD-07 | No input sanitisation visible in compiled code | High | Audit all form inputs for injection risk |
| TD-08 | Session fixation not explicitly handled | Medium | Ensure session regeneration on login |
| TD-09 | No duplicate entity detection | High | Add uniqueness check in `DatabaseOperations` |
| TD-10 | Approved record can be filtered but not truly locked | Low | Add `is_locked` flag; prevent edits post-approval |

---

## 8. Email Service

```java
// Three email utility classes detected in com.qd.utlils:
// EmailUtil         — plain text email
// HtmlEmailSender   — HTML email
// SendEmail         — dispatch wrapper

// SMTP Configuration (from KycConfig.properties):
smtp_host = relay.qataridiar.com
smtp_port = 25
smtp_sender_email = kycreport@qataridiar.com
```

Emails are triggered at:
- KYC submission (notify approver)
- Approval/rejection (notify contributor)
- RFI issued/responded (notify relevant party)

---

## 9. PDF Generation

`PrintController` managed bean:
- Renders full KYC report to PDF
- Applies **Draft watermark** when `qd_kyc_wf_status != 'APPROVED'`
- Applies header/footer via page event classes in `com.qd.utlils`
- Output saved to `/u01/documents/reports/` and served as HTTP download

---

## 10. Security Assessment Summary

| Control | Current State | Recommendation |
|---|---|---|
| Authentication | Username/password form | Acceptable; add MFA for approvers |
| Password storage | Plain text | **Immediate fix required: BCrypt** |
| Session management | 30-min timeout | Acceptable |
| CSRF | JSF ViewState provides basic protection | Verify `STATE_SAVING_METHOD` config |
| SQL injection | Hibernate ORM provides parameterised queries | Audit any native SQL in DatabaseOperations |
| Authorisation | Role checked via session attribute | Acceptable pattern; add server-side checks |
| Audit log | ProcessLog insert-only | Good — maintain this constraint |
| Document access | File path served directly | Risk: path traversal possible. Serve via controlled servlet |
