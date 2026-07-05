# Version 4 — Business User Guide
# Oracle APEX KYC System

**Document Type:** Business User Guide  
**Version:** V4  
**Audience:** All system users — Requestors, Contributors, Approvers, Administrators  
**Platform:** Oracle APEX 23.2 — accessible from any web browser  
**Login:** Your existing Oracle Fusion / company network credentials  

---

## Welcome to the New KYC System

The new KYC system is built on **Oracle APEX** and is fully connected to the company's Oracle Fusion system. This means:

- **No new username or password.** You log in with the same credentials you use for Oracle Fusion.
- **Your details are already in the system.** Your name, department, and email come directly from your Fusion employee record.
- **Your role is set automatically.** Based on your job role in Fusion, the system knows whether you are a Requestor, Compliance Officer (Contributor), Approver, or Administrator.

---

## How to Log In

1. Open your web browser and go to the KYC system address (provided by IT)
2. You will be redirected to the company's login page (the same page used for other systems)
3. Enter your Fusion/network username and password
4. The system opens directly on your personalised home page

---

## What You See Depends on Your Role

| Your Role | What You See | Where You Start |
|---|---|---|
| **Requestor** (any QD employee) | Intake portal only — submit requests, track your submissions | Request Status page |
| **Contributor** (Compliance Officer) | Full KYC system — create entities, write reports, manage your queue | My Worklist |
| **Approver L1** | Approval queue — review and act on submitted reports | Approval Queue |
| **Approver L2 / MLRO** | Final approval queue — high-stakes reviews with SAR gate | L2 Approval Queue |
| **Administrator** | Everything above, plus user management and reference data | Executive Dashboard |

---

## For Requestors: Submitting a KYC Request

### Step 1 — Open the Request Form

From your home page, click **"New KYC Request"**. The form opens with your name and department already filled in.

### Step 2 — Tell Us About the Counterparty

Fill in the details of the person or company you want to do business with:
- Their name and country
- Whether they are an individual or a company
- The type of relationship (supplier, buyer, tenant, etc.)
- Whether there is any financial involvement
- Whether there are any known connections to other QD relationships

### Step 3 — The System Checks Whether a KYC Is Needed

Based on your answers, the system automatically decides whether a full KYC report is required or whether a simplified evidence record is sufficient. This replaces the Excel calculator.

```
If KYC Not Required:
  → A waiver record is created automatically
  → Your documents are safely stored as evidence
  → You receive a confirmation

If KYC Required:
  → Continue to document upload
```

### Step 4 — Upload Your Documents

The system shows you a checklist of which documents are needed based on the type of entity and their country. Upload each document and label its type (e.g., Commercial Registration, Passport, Ownership Declaration).

### Step 5 — Submit

Click **Submit**. You will receive a confirmation with your unique case reference number (e.g., `INTAKE-2025-000123`).

### Tracking Your Request

Go to **"My Requests"** at any time to see the current status of all your submissions:

| Status | Meaning |
|---|---|
| Pending Review | Compliance team is reviewing your documents |
| Documents Needed | Compliance team has requested additional information |
| In Progress | Your KYC is being worked on |
| Awaiting Approval | Report is with the approver |
| Approved | KYC complete — you will receive the report by email |
| Rejected | KYC could not be approved — see the reason in the system |

---

## For Compliance Officers: Your Daily Workflow

### My Worklist

When you log in, your **Worklist** shows everything that needs your attention, organised by priority:
- New cases assigned to you
- Reports you have drafted but not yet submitted
- Reports that have been sent back to you with a request for more information (RFI)
- SLA status: which reports are approaching or past their target completion date (green/amber/red)

### Creating an Entity

Before writing a KYC report, you record the counterparty as an **Entity** in the system.

**Step 1: Duplicate Check**  
Type the entity's name. The system searches existing records automatically and shows you similar names already in the system. If the same company exists, you can link to it rather than creating a duplicate.

**Step 2: Fill in Entity Details**  
The form adjusts based on whether the counterparty is an individual or a company. For companies, you also add the UBOs and authorised signatories.

**Step 3: Record Screening Results**  
After running WorldCheck (or your screening tool), come back to the system and complete the structured screening section:
- When you screened them
- Which database you used
- Whether there was a match, and if so — genuine or false positive
- Whether they are a PEP
- Your findings in free text

> **Why this matters:** These structured fields are what a regulator or auditor will look at if they examine your work. A free-text paragraph is harder to stand behind than a clear, structured record.

### Creating a KYC Report

Click **New KYC Report** and select the entity you just created. The system pre-fills everything it already knows from the entity record and the intake form — you will not be re-typing data you already entered.

**What you fill in:**
- KYC Type (Simplified / Ad Hoc / Enhanced)
- Risk Level — the system suggests one based on the entity's country and screening results. If you disagree, you can change it, but you must note why.
- Conclusion — select a template from the dropdown, and the standard text appears in the conclusion field, ready for you to personalise
- Next Steps

The form shows your **SLA indicator**: how many days have passed versus your target completion time. Green means on track. Amber means approaching the limit. Red means you are past it.

**Save as Draft** if you need to come back to it.  
**Submit for Approval** when the report is complete.

### Responding to an RFI

When an approver sends a report back to you with a question:
1. You receive an email notification
2. Go to your Worklist — the report is there with a flag
3. Click the report, read the approver's comment in the **History** tab
4. Make the necessary changes or add a response in the comments section
5. Resubmit

---

## For Approvers: Reviewing Reports

### Your Approval Queue

Your queue shows all reports waiting for your review. Each row shows:
- Report reference and counterparty name
- KYC type and risk level (colour-coded: red = high, amber = medium, green = low)
- Who submitted it and when
- Days pending versus SLA target

### Reviewing a Report

Click **Review** on any report. A review panel opens with four tabs:

| Tab | Content |
|---|---|
| **Summary** | All KYC fields, risk assessment, conclusion |
| **Entity & UBOs** | Entity details, UBO list, structured screening results per UBO |
| **Documents** | Attached files — click to view inline in the browser |
| **History** | Every action taken on this report, with dates, users, and comments |

### Taking Action

After reviewing, scroll to the bottom of the panel:

**Approve**  
- For low-risk reports: this is the final approval — report is complete, requestor is notified automatically
- For medium/high-risk: passes to the Level 2 queue

**Request For Information (RFI)**  
- Select the type of issue (Missing Document / Unclear Conclusion / Insufficient Screening / Other)
- Enter your comment
- Click Send — the report returns to the contributor with your question

**Reject**  
- Enter the reason (mandatory)
- The report is closed and both the contributor and requestor are notified

### When You Are on Leave

Go to your profile and mark yourself as **On Leave**. Your pre-configured deputy (set by your administrator) will automatically receive your tasks. When you return, unmark yourself — your queue resumes immediately.

---

## For Level 2 / MLRO Approvers

The Level 2 process is the same as Level 1, with one additional step before you can approve:

### The SAR Gate

Before completing a final approval, you must answer:

> *"Based on your review of this report, does any information warrant a Suspicious Activity Report (SAR)?"*

- **No** → proceed to approve normally
- **Yes** → the approval is paused; the Head of Compliance and system administrator are notified; the SAR process follows separately

This is not bureaucracy — it is a legal obligation. The system ensures it is never skipped.

---

## For Administrators

### User Management

Go to **Administration → User Management** to see all users synchronised from Oracle Fusion. The system automatically imports all active employees. You can:
- Override a user's KYC role if their Fusion job code does not map correctly
- Set a deputy approver for each approver
- Mark an approver as on leave (activates their deputy)
- View the delegation log

> **Note:** You do not create or delete users manually. The system syncs with Fusion nightly. New employees appear automatically; those who leave are deactivated automatically.

### Reference Data

All configurable lists are managed under **Administration → Reference Data**:
- Business Counterparty Categories
- Relationship Types
- Conclusion Templates (by risk level)
- Country Risk Tiers (FATF status)
- Report Statuses

Changes take effect immediately for all new records.

### Monitoring Dashboard

The **Executive Dashboard** shows real-time KPIs:

| Panel | Shows |
|---|---|
| Pipeline Summary | What is currently in each stage |
| Completed This Month | Count + average days to complete |
| SLA Compliance | % of reports finished on time |
| Risk Breakdown | Low / Medium / High pie chart |
| Overdue | Cases past their SLA target |
| Upcoming Reviews | KYCs due for renewal in the next 60 days |

---

## Frequently Asked Questions

**Q: What if I submitted a request and need to add more documents?**  
A: Go to My Requests, open the request, and use the "Add Document" button. Documents can be added at any stage before final approval.

**Q: What if my approver is on holiday and no one is reviewing my report?**  
A: The system handles this automatically. When an approver marks themselves on leave, their deputy receives the tasks. If you believe there is a routing problem, contact your compliance administrator.

**Q: How do I know when my KYC request is complete?**  
A: You will receive an email with the completed report attached. You can also check My Requests in the portal at any time.

**Q: Can I edit a report after submitting it for approval?**  
A: Not directly — once submitted, the report is in the approver's hands. If something needs to change, the approver can issue an RFI, which returns it to you for editing.

**Q: How long is my session active?**  
A: Your session expires after 30 minutes of inactivity. You will be redirected to the login page.

**Q: What happens to old KYC records?**  
A: All records are retained for at least 5 years after approval. They remain searchable and viewable throughout this period.
