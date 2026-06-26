# Version 1 — Business Overview
# Current KYC Management Application

**Document Type:** Business Overview  
**Audience:** Compliance Team, Management, Business Stakeholders  
**System:** Existing JSF Web Application  
**Status:** Live Production System  

---

## What Is This System?

The KYC Management Application is Qatari Diar's internal web-based system for managing **Know Your Customer (KYC)** due diligence reports. It replaces paper files and email chains with a digital record of every counterparty screened by the Enterprise Risk & Compliance team.

A **counterparty** is any person or company that Qatari Diar plans to do business with — a supplier, buyer, tenant, contractor, investor, or joint venture partner.

Before QD enters into a significant business relationship, the compliance team must research the counterparty, verify their identity, assess any risks, and obtain management approval. This system manages that process from start to finish.

---

## Who Uses It?

| Role | What They Do in the System |
|---|---|
| **Contributor** | Compliance officer who creates and submits KYC reports |
| **Level 1 Approver** | Reviews and approves reports for low-risk cases; first reviewer for medium/high risk |
| **Level 2 / RFI Approver** | Final sign-off for medium and high-risk cases; handles information requests |
| **Administrator** | Manages users, reference data, and system configuration |

---

## What Does the System Do?

### 1. Manages Counterparty Records (Entities)

Before creating a KYC report, the compliance team records information about the counterparty in the system. This is called an **Entity**.

For a **natural person** (an individual), the system captures:
- Full name, nationality, date of birth
- ID or passport number
- Screening results from international databases

For a **legal entity** (a company), the system captures:
- Company name, registration number, headquarters
- Ownership structure
- Details of the people who ultimately own or control the company — these are called **Ultimate Beneficial Owners (UBOs)**

Each UBO's identity is recorded individually, including their nationality, ID number, and the results of screening them through international databases.

### 2. Creates and Manages KYC Reports

A KYC report is the formal compliance document that records everything the team has found about a counterparty and what decision was reached.

Each report includes:
- Which company or person was investigated
- What type of relationship QD plans to have with them
- What level of due diligence was applied (Simplified, Standard, or Enhanced)
- What the screening found
- The compliance officer's conclusion and recommendation
- The assessed risk level (Low, Medium, or High)
- Supporting documents

### 3. Routes Reports Through an Approval Process

Once a compliance officer completes a report, it goes through a formal approval process before it is finalised.

```
Compliance Officer
  creates report
       │
       ▼
  Submits for approval
       │
       ▼
Level 1 Approver reviews
       │
  ┌────┴────────┬─────────────┐
  ▼             ▼             ▼
Approve      Request       Reject
(low risk)   more info     (closed)
  │             │
  │     Officer responds
  │     and resubmits
  │             │
  └─────────────┘
       │
  (medium/high risk only)
       ▼
Level 2 Approver reviews
       │
  ┌────┴────────┬─────────────┐
  ▼             ▼             ▼
Final         Request       Reject
Approval      more info     (closed)
```

**Important rule:** A report cannot be approved by the same person who created it. Low-risk reports require one approval signature. Medium and high-risk reports require two separate approvals.

### 4. Tracks Everything with a Full Audit Trail

Every action taken — every submission, approval, rejection, or request for information — is permanently recorded with the date, time, and the name of the person who took the action. This audit trail cannot be edited or deleted.

### 5. Stores Supporting Documents

The system holds all documents submitted as evidence: commercial registrations, identity documents, shareholder certificates, and any other supporting material. These documents are linked directly to the KYC report they support.

### 6. Generates PDF Reports

The system can produce a formal PDF version of any KYC report. Unfinished reports are watermarked as "Draft" to prevent them from being used as official documents.

### 7. Provides Search and Filtering

The compliance team can search the full history of KYC reports by:
- Reference number
- Counterparty name
- Risk level (Low / Medium / High)
- Approval status
- Report status
- The officer who conducted the due diligence

---

## How a KYC Report Moves Through the System

### Step-by-Step

**Step 1 — Create the Entity**  
The compliance officer creates a record for the counterparty, entering their details and the results of searching them against international screening databases (WorldCheck and others).

**Step 2 — Add UBOs (if a company)**  
If the counterparty is a company, the officer records each significant owner or authorised signatory — including their screening results.

**Step 3 — Create the KYC Report**  
The officer creates the formal report, linking it to the entity, classifying the type of due diligence, recording the findings and conclusion, setting the risk level, and attaching supporting documents.

**Step 4 — Save as Draft or Submit**  
The officer can save a draft to complete later, or submit the finished report for approval.

**Step 5 — Level 1 Review**  
The appointed Level 1 Approver reviews the full report, including all documents. They can approve it, send it back with questions, or reject it.

**Step 6 — Level 2 Review (Medium/High Risk)**  
For anything above low risk, a second senior approver independently reviews and makes the final decision.

**Step 7 — Completion**  
Once fully approved, the report is finalised and archived. A PDF can be generated and sent to the team that originally requested the KYC.

---

## Reference Data the System Manages

The system uses configurable reference tables that administrators can update without changing the software:

- **Business Counterparty Categories** — e.g., Supplier, Buyer, Investor, Tenant
- **Report Statuses** — with colour codes for quick visual identification
- **Screening Results** — categories for what the international databases returned
- **Request Originators** — the teams or individuals who requested KYC checks

---

## What the System Does Not Currently Do

Being transparent about current limitations helps set expectations:

| Limitation | Impact |
|---|---|
| No automatic notification to the original requester when a report is approved | Requesters must be informed manually |
| No live KPI dashboard — metrics require a manual data export | Management reporting is slow and labour-intensive |
| No scheduled reminders for periodic KYC reviews | Overdue reviews are not flagged automatically |
| No digital intake from requesting departments — requests arrive by email | Inconsistent formats, no tracking |
| Passwords are not strongly secured | Security risk that should be addressed |

These limitations are addressed in **Version 3 (Best Practice)** and **Version 4 (APEX Implementation)**.

---

## Key Terms

| Term | Meaning |
|---|---|
| **KYC** | Know Your Customer — the process of verifying who a counterparty is and assessing their risk |
| **Counterparty** | Any person or company QD does business with |
| **Entity** | The system record for a counterparty |
| **UBO** | Ultimate Beneficial Owner — the natural person who ultimately owns or controls a legal entity |
| **Due Diligence** | The investigation and research process |
| **SDD** | Simplified Due Diligence — applied to low-risk cases |
| **EDD** | Enhanced Due Diligence — applied to high-risk cases |
| **PEP** | Politically Exposed Person — someone in a prominent public position |
| **Workflow Status** | Where a report currently sits in the approval process |
| **Process Reference** | The unique ID number assigned to each KYC report |
| **Audit Trail** | The permanent, tamper-proof record of every action |
