# V6 — Business User Guide
## Qatari Diar KYC Management System
**Platform:** Oracle APEX 26 (AI-First Release) | Oracle ATP 23ai | OCI IAM SSO
**Document version:** 6.0 | June 2026
**Audience:** Business users — Requestors, Compliance Officers, Approvers, MLRO, Administrators

---

## Table of Contents

1. [Welcome and What's New](#1-welcome-and-whats-new)
2. [How AI Works in This System](#2-how-ai-works-in-this-system)
3. [How to Log In](#3-how-to-log-in)
4. [Role Overview](#4-role-overview)
5. [For Requestors](#5-for-requestors)
6. [For Compliance Officers](#6-for-compliance-officers)
7. [For Approvers](#7-for-approvers)
8. [For Level 2 / MLRO](#8-for-level-2--mlro)
9. [For Administrators](#9-for-administrators)
10. [Frequently Asked Questions](#10-frequently-asked-questions)

---

## 1. Welcome and What's New

Version 6 of the Qatari Diar KYC Management System is built on Oracle APEX 26, Oracle's AI-first release, and runs on Oracle Autonomous Transaction Processing (ATP) with Oracle Database 23ai. The core KYC workflow — five phases from entity registration through approval — is unchanged. What has changed is the level of AI assistance available to officers and approvers at key points in that workflow.

The AI features are designed to reduce manual effort on routine analytical tasks, improve consistency, and help officers focus their attention where it matters most. No AI feature makes a final decision. Every AI suggestion requires a human action to take effect.

### What's New — AI Feature Summary

| Feature | Where it appears | Who benefits |
|---|---|---|
| Risk Pre-Assessment | Phase 2 — Risk Classification | Compliance Officers |
| Duplicate Entity Detection | Phase 1 — Entity Registration | Compliance Officers |
| Document Classification | Phase 1 — Document Upload | Compliance Officers |
| Conclusion Drafting | Phase 5 — Report Finalisation | Compliance Officers |
| AI Summary Panel | Review screen | Approvers |
| SAR Risk Indicator | Level 2 / MLRO escalation view | MLRO |
| Natural Language Search | Global search bar | All roles |
| APEX AI Assistant | In-app help panel | All roles |

---

## 2. How AI Works in This System

Before using any AI-assisted feature, read the following principles. They apply to every AI function in the system.

- **AI suggests, you decide.** Every AI output is a suggestion. No report is submitted, no risk level is set, and no conclusion is recorded without an officer or approver explicitly confirming or editing it.
- **You can always override.** If you disagree with an AI suggestion, select Override, enter a brief reason, and proceed with your own assessment. Overrides are as valid as acceptances — neither choice affects your standing.
- **Confidence is shown, not hidden.** Each AI suggestion displays a confidence indicator (High / Medium / Low). A low-confidence suggestion means the AI has limited signal and you should rely more heavily on your own review.
- **Everything is logged.** Every AI suggestion, along with whether it was accepted or overridden, the officer's reason (if overriding), and the timestamp, is written to the AI Audit Log. This log is available to Administrators and the MLRO.
- **AI does not access external systems in real time.** The AI works from data already held in the KYC system and OCI-hosted models. It does not browse the internet or query live sanctions databases during a session.

!!! note "Regulatory position"
    AI assistance is a decision-support tool. Compliance officers and approvers remain fully accountable for all KYC determinations. The AI Audit Log supports any regulatory review of how decisions were reached.

---

## 3. How to Log In

Login is unchanged from V5. The system uses OCI Identity and Access Management (IAM) with Single Sign-On.

1. Open your browser and navigate to the KYC system URL provided by your Administrator.
2. You are redirected to the OCI IAM login page.
3. Enter your corporate email address and password. If your organisation uses multi-factor authentication, complete the MFA step.
4. On successful authentication, you are returned to the KYC dashboard. The dashboard displayed depends on your assigned role.

!!! tip "Session timeout"
    Sessions expire after 30 minutes of inactivity. Save work in progress before stepping away. Draft records are preserved automatically but unsaved form fields are not.

!!! warning "Access problems"
    If you cannot log in, or if you can log in but cannot see the expected menu items, contact your KYC System Administrator. Do not share your credentials with colleagues.

---

## 4. Role Overview

| Role | Primary responsibility | AI features available |
|---|---|---|
| Requestor | Submit new KYC requests and upload documents | Natural Language Search, APEX AI Assistant |
| Compliance Officer | Conduct due diligence, classify risk, draft report | All AI workflow features |
| Approver (Level 1) | Review and approve or return officer reports | AI Summary Panel, Natural Language Search |
| Level 2 / MLRO | Handle escalations, SAR decisions | SAR Risk Indicator, AI Audit Log (read), Natural Language Search |
| Administrator | System configuration, user management, AI settings | AI Model Configuration, AI Audit Log (full), Confidence Threshold Settings |

---

## 5. For Requestors

The requestor experience is unchanged in V6. Requestors initiate KYC cases and upload supporting documents. You will notice that the Natural Language Search and the APEX AI Assistant (the help panel, bottom-right of the screen) are now available. These are described in sections 6.5 and 6.6. No other AI features are visible to the Requestor role.

### 5.1 Submitting a New KYC Request

1. From your dashboard, select **New KYC Request**.
2. Complete the entity details form: legal name, country of incorporation, entity type, and primary contact.
3. Upload required documents. The system will confirm receipt of each file.
4. Submit the request. The case moves to Phase 1 — Entity Registration and is assigned to the Compliance Officer queue.

### 5.2 Tracking Your Request

Use the **My Requests** tab to see the current phase and status of each case you have submitted. You will receive an email notification when the case moves to a new phase or when additional information is required from you.

---

## 6. For Compliance Officers

Compliance officers conduct the substantive due diligence. V6 introduces AI assistance at four points in the workflow. At each point, the AI suggestion is clearly labelled and the officer takes a deliberate action to accept or override it.

### 6.1 Phase 1 — Entity Registration and Document Upload

**Duplicate Entity Detection**

When you enter the entity name and submit the registration form, the system runs a semantic similarity check using OCI AI Vector Search. This replaces the Jaro-Winkler fuzzy matching used in V5. The new approach catches name variations, translations, and abbreviations that character-matching would miss.

If a potential duplicate is found, a yellow banner appears above the form:

!!! warning "Potential duplicate detected"
    The AI has identified one or more existing entities with a similar name. Review the matches below before proceeding.

Each suggested match is listed with the entity name, jurisdiction, current status, and the similarity score. Review each one:

- If it is the same entity, open the existing record and do not create a new case.
- If it is a different entity, select **Confirm — Not a Duplicate** and add a brief note explaining why (for example, different jurisdiction or ownership structure). The case then proceeds.

If no duplicates are found, registration continues without interruption.

**Document Classification**

After documents are uploaded, the AI classifies each file by document type: Commercial Registration, Trade Licence, Passport, Ownership Declaration, Financial Statements, and so on. Classifications appear alongside each uploaded file within a few seconds of upload.

!!! info "Document classification results"
    Each document shows a detected type and a confidence indicator. Review classifications before proceeding. Correct any that are wrong by selecting the document type from the dropdown.

If the AI detects that a document type required for the selected KYC level appears to be missing, a warning is shown:

!!! warning "Possible missing document"
    No document classified as Ownership Declaration has been uploaded. This document type is required for Enhanced KYC. Upload the document or confirm it is not applicable.

You must either upload the missing document or explicitly mark it as not applicable with a reason before the case can advance.

### 6.2 Phase 2 — Risk Classification

**AI Risk Pre-Assessment**

After entity registration is complete, the system performs an AI risk pre-assessment before you open the risk classification form. The AI analyses the entity's country of incorporation, ownership structure, nature of business, and any prior screening history within the system.

The result is presented at the top of the risk classification screen:

!!! info "AI Risk Pre-Assessment"
    **Suggested risk level: MEDIUM**
    **Confidence: High**
    The entity is incorporated in a jurisdiction classified as medium-risk under the current country risk matrix. The disclosed ownership structure includes one beneficial owner with a 35% stake whose nationality is flagged in the risk register. No prior adverse screening history is recorded in this system.

Review the explanation. Then take one of the following actions:

- **Accept** — The suggested risk level is applied to the form. You confirm it as your own assessment before submitting.
- **Override** — Select the risk level you assess to be appropriate, enter a reason for overriding the AI suggestion, and submit. Your override and reason are logged.

!!! note "The AI suggestion is a starting point"
    The pre-assessment is based on structured data already in the system. You may have information from documents, external searches, or professional judgement that the AI does not have. Always review the full entity profile before confirming a risk level.

### 6.3 Phase 3 and Phase 4 — Screening and Enhanced Due Diligence

No AI features are introduced in Phases 3 or 4 in this release. Screening results are returned from the external screening provider as in V5. Enhanced due diligence checklists and PEP review steps are unchanged.

### 6.4 Phase 5 — Report Finalisation

**AI Conclusion Drafting**

When you reach the conclusion section of the KYC report, an AI-generated draft conclusion is pre-populated in the text field. The draft is based on the entity data, screening results, and confirmed risk level recorded during the case.

The draft is clearly labelled:

!!! info "AI-generated draft — review and edit before submitting"
    This text was generated by the AI assistant. It is a starting point. Edit it to reflect your professional assessment, add any relevant detail not captured above, and remove anything you consider inaccurate or incomplete.

Edit the conclusion as needed. You are not required to retain any part of the AI-generated text. The version you submit is your conclusion. The original AI draft is preserved in the case history for audit purposes.

Do not submit the AI draft unedited. It will not contain case-specific detail that only you hold, and an unedited draft does not constitute a professional assessment.

### 6.5 Natural Language Search

The global search bar at the top of every screen accepts plain English queries. Examples:

- *show me high-risk entities from Egypt approved in the last 6 months*
- *entities with Enhanced KYC in progress assigned to me*
- *cases where the conclusion was overridden by the approver this year*

The system interprets the query and returns a filtered results list. You can refine results using the standard filter controls once the results are returned. Natural language search does not replace the structured Advanced Search — both remain available.

### 6.6 APEX AI Assistant

The AI Assistant is accessible via the help panel icon at the bottom-right of the screen. It can answer questions about the KYC process and system operation. Examples:

- *What documents are required for an Enhanced KYC on a Jordanian company?*
- *How do I reassign a case to another officer?*
- *What does a Medium risk classification mean under the current policy?*

The assistant answers based on the system's policy configuration and APEX documentation. It does not have access to individual case data and cannot advise on decisions for a specific entity. For case-specific guidance, consult your team lead or compliance manager.

---

## 7. For Approvers

Approvers review completed KYC reports submitted by compliance officers and either approve, return with comments, or escalate.

### 7.1 AI Summary Panel

When you open a case for review, an AI Summary Panel appears at the top of the report. This panel provides a condensed overview of the case to help you orient quickly before reading the full report.

The summary includes:

- Entity name, type, and jurisdiction
- Confirmed risk level and whether it was accepted or overridden from the AI suggestion
- Screening result (clear / adverse / pending clarification)
- Whether any AI suggestions were overridden during the case, and the recorded reasons
- Any AI flags raised during document classification or duplicate detection

!!! info "AI Summary Panel"
    This panel is generated from structured case data. It is a navigation aid, not a substitute for reading the full report. Approval decisions must be based on the complete case record.

### 7.2 AI Flags on Reports

If any AI suggestion was overridden by the officer, or if any document classification warning was acknowledged without uploading the flagged document, the report is marked with an AI Review flag in the case list. This allows you to identify cases that may warrant closer scrutiny before approving.

AI flags are informational. They do not prevent approval. If you are satisfied with the officer's documented reasons, you may approve normally.

### 7.3 Review Actions

Review actions are unchanged from V5:

- **Approve** — Case moves to the approved register.
- **Return to Officer** — Case is returned with your comments for revision.
- **Escalate to Level 2 / MLRO** — Case is forwarded for enhanced review.

---

## 8. For Level 2 / MLRO

The MLRO handles cases escalated from Level 1 approval, typically those involving high-risk entities, adverse screening results, or PEP involvement.

### 8.1 SAR Risk Indicator

For escalated cases, the MLRO view includes an AI-generated SAR Risk Indicator. This is an advisory signal, not a recommendation to file or not to file a Suspicious Activity Report.

The indicator presents:

- A risk signal level (Elevated / Standard) based on the combination of risk classification, screening outcomes, ownership structure, and transaction indicators where available
- A brief explanation of the factors contributing to the signal
- A confidence level

!!! warning "SAR decisions are yours alone"
    The SAR Risk Indicator is advisory only. The decision to file a SAR rests entirely with the MLRO, based on professional judgement, legal advice, and regulatory obligation. The AI signal must not be treated as a determination.

The SAR Risk Indicator and the MLRO's decision (file / do not file / defer) are both recorded in the case history.

### 8.2 AI Audit Log Access

The MLRO has read access to the AI Audit Log for all cases. This log shows every AI suggestion made during a case, the confidence level at the time, the officer's action (accepted or overridden), the reason given for any override, and the timestamp. This is available from the Case Detail screen under the **Audit** tab.

---

## 9. For Administrators

### 9.1 AI Model Configuration

Administrators can view and update the AI model settings from **Administration > AI Settings > Model Configuration**. The following settings are available:

- **Active model version** — Displays the OCI AI model version currently in use. Model updates are managed by the platform team; this field is read-only unless you have platform administration rights.
- **Feature toggles** — Each AI feature (Risk Pre-Assessment, Duplicate Detection, Document Classification, Conclusion Drafting) can be individually enabled or disabled. Disabling a feature does not remove the underlying data; it suppresses the AI output in the user interface.
- **Country risk matrix** — The risk matrix used by the Risk Pre-Assessment feature is maintained here. Update it when the organisation's country risk ratings change.

### 9.2 Confidence Threshold Settings

Each AI feature has a configurable minimum confidence threshold. Suggestions below the threshold are suppressed rather than shown to officers. The default thresholds are:

| Feature | Default threshold |
|---|---|
| Risk Pre-Assessment | Medium |
| Duplicate Detection | Medium |
| Document Classification | Low |
| Conclusion Drafting | High |

Lowering a threshold increases the volume of suggestions shown, including lower-confidence ones. Raising a threshold reduces suggestions but increases the risk that borderline cases are not flagged. Discuss changes with your compliance manager before adjusting thresholds.

### 9.3 AI Audit Log

The full AI Audit Log is available at **Administration > AI Settings > Audit Log**. You can filter by feature, date range, officer, action (accepted / overridden), and confidence level. The log can be exported to CSV for offline review or regulatory submission.

Audit log records are retained for seven years in line with the organisation's data retention policy and cannot be deleted through the application interface.

### 9.4 User and Role Management

User and role management is unchanged from V5. Assign roles via **Administration > Users**. AI features are governed by role; there are no additional AI-specific permissions beyond those in the role overview table in section 4.

---

## 10. Frequently Asked Questions

**Can the AI approve a KYC report?**

No. The AI cannot approve, reject, or escalate a case. Only a user with the Approver role can take approval actions. The AI provides information to support the approver's decision; it does not act on its own.

**What if I disagree with the AI risk suggestion?**

Select Override, choose the risk level you assess to be correct, and enter a brief reason. Your assessment takes effect and is recorded as the confirmed risk level. The AI suggestion and your override reason are preserved in the case history. There is no penalty or flag for overriding — overrides are expected and normal.

**Is AI usage logged?**

Yes. Every AI suggestion, the confidence level, the officer's response (accepted or overridden), the reason given for any override, and the timestamp are written to the AI Audit Log. Administrators and the MLRO can access this log. It is retained for seven years.

**What does the confidence indicator mean?**

The confidence indicator reflects how much signal the AI model had when generating a suggestion. High confidence means the model had clear, consistent input data. Medium confidence means the input was partially ambiguous. Low confidence means the model had limited data and its suggestion should be treated with greater caution. You can override a suggestion at any confidence level.

**Can the AI assistant access my cases?**

No. The APEX AI Assistant answers general process and policy questions. It does not have access to individual case records, entity data, or screening results. For guidance on a specific case, consult your compliance manager.

**What happens if the AI is unavailable?**

If the AI service is unavailable, AI-assisted fields are hidden and the workflow continues without them. Officers complete risk classification, document review, and conclusion writing manually, as in V5. The system does not block progress when AI features are offline. Administrators are notified via the system health dashboard.

**Does the AI learn from my decisions?**

The AI models used in this system are hosted on OCI and are not retrained using individual decisions made within the Qatari Diar KYC system. Model updates are managed at the platform level and follow a controlled release process. Any update to the active model version is recorded in the AI Model Configuration screen.

**Who do I contact if an AI suggestion appears to be wrong or misleading?**

Report the issue to your KYC System Administrator and note the case number, the feature involved, and the nature of the concern. Administrators can review the AI Audit Log entry and escalate to the platform team if a model issue is suspected. In the meantime, override the suggestion and document your reasoning as normal.

**Is the conclusion drafted by the AI acceptable to submit as-is?**

No. The AI-generated conclusion draft is a starting point. It must be reviewed, edited, and personalised by the officer before submission. An unedited draft does not constitute a professional assessment and may be returned by the approver. The system does not technically prevent submission of an unedited draft, but doing so is contrary to policy.

**Where can I find training materials?**

Training materials for V6, including recorded walkthroughs of the AI-assisted workflow steps, are available on the internal intranet under Compliance > KYC System > Training. For system access issues, contact your KYC System Administrator.

---

*Document prepared for Qatari Diar Real Estate Investment Company — Internal use only.*
*Version 6.0 | June 2026 | KYC System Programme*
