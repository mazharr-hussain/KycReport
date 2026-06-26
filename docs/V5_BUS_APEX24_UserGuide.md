# Version 5 — Business User Guide
# Qatari Diar KYC Management System

**Document Type:** Business User Guide
**Audience:** All system users — Requestors, Compliance Officers, Approvers, Administrators
**Platform:** Oracle APEX 24.2 on Oracle Autonomous Transaction Processing (ATP) — Oracle Database 23ai
**Login:** Your company SSO credentials (via OCI IAM)
**Version:** V5

---

## Welcome to Version 5

Version 5 of the KYC Management System moves the platform to **Oracle APEX 24.2** running on **Oracle Autonomous Transaction Processing (ATP) — Oracle Database 23ai**. From a business perspective, the process for submitting, reviewing, and approving KYC reports is identical to Version 4. The upgrade brings a more reliable cloud infrastructure, better performance under load, improved document storage, and a significantly better experience on mobile devices.

### What Is New in Version 5

| Area | Version 4 (APEX 23.2) | Version 5 (APEX 24.2, ATP 23ai) |
|---|---|---|
| Login | Oracle IDCS (Identity Cloud Service) | OCI IAM (Oracle Cloud Infrastructure IAM) — same company SSO, updated behind the scenes |
| Workflow notifications | Email only | Native APEX Workflow notifications in the top navigation bar, plus email |
| Approval interface | Custom approval screen | Native APEX Workflow task panel — cleaner, faster, mobile-friendly |
| Document storage | Database attachment (BLOB) | OCI Object Storage — no file size constraints, faster download |
| Mobile / tablet | Limited | Full Progressive Web App (PWA) — install on your phone like an app |
| AI features | None | None — AI features are planned for Version 6 |
| Database | Oracle Database 19c | Oracle Database 23ai on ATP |

!!! note
    The KYC process steps — intake, entity creation, report writing, approval, and closure — are unchanged. If you are familiar with Version 4, you will find Version 5 immediately recognisable.

---

## How to Log In

1. Open your web browser (or the installed PWA on your phone) and navigate to the KYC system address provided by IT.
2. You will be redirected to the **company single sign-on page**, which now uses **OCI IAM**. The page looks slightly different from the previous login screen, but your credentials are the same.
3. Enter your company username and password. If your organisation uses multi-factor authentication (MFA), you will be prompted for your second factor as usual.
4. The system opens directly on your personalised home page.

!!! note
    You do not need a separate KYC system password. OCI IAM is the same identity service that manages your access to other Oracle Cloud applications at Qatari Diar. Contact IT if your login fails — do not attempt to reset your password from the KYC login page.

!!! tip
    On a mobile device or tablet, you can install the KYC system as a Progressive Web App (PWA). Tap the "Add to Home Screen" option when prompted by your browser. Once installed, the app launches full-screen and works offline for read-only tasks.

---

## What You See Depends on Your Role

| Your Role | What You See | Where You Start |
|---|---|---|
| **Requestor** (any QD employee) | Intake portal — submit requests and track your submissions | My Requests |
| **Compliance Officer** (Contributor) | Full KYC workspace — entity creation, report writing, worklist management | My Worklist |
| **Approver Level 1** | Approval queue — review and act on submitted reports | Workflow Task Inbox |
| **Approver Level 2 / MLRO** | Final approval queue with SAR gate | Workflow Task Inbox (L2) |
| **Administrator** | Everything above, plus user management, reference data, and the monitoring dashboard | Executive Dashboard |

Your role is assigned automatically based on your job profile. If you believe your role is incorrect, contact your KYC system administrator.

---

## For Requestors: Submitting a KYC Request

### Step 1 — Open the Request Form

From your home page, click **"New KYC Request"**. The form opens with your name, department, and contact email already filled in from your OCI IAM profile.

### Step 2 — Tell Us About the Counterparty

Complete the details of the person or company you want to do business with:

- Their name and country of incorporation or residence
- Whether they are an individual or a legal entity (company, fund, partnership)
- The type of business relationship (supplier, buyer, tenant, joint venture partner, etc.)
- Whether the relationship involves a financial transaction or payment
- Whether there are any known connections to existing Qatari Diar relationships

### Step 3 — The System Determines Whether a Full KYC Is Required

Based on your answers, the system applies the KYC decision matrix and tells you whether a full KYC report is required or whether a simplified evidence record is sufficient.

```
If KYC Not Required:
  → A waiver record is created and stored automatically
  → Your supporting documents are retained as evidence
  → You receive a confirmation with a reference number

If KYC Required:
  → Continue to document upload (Step 4)
```

### Step 4 — Upload Your Documents

A document checklist is displayed, tailored to the entity type and country. Upload each required document and select the appropriate document type from the list (for example: Commercial Registration, Passport Copy, Ownership Declaration, Audited Accounts).

!!! tip
    Documents are now stored in **OCI Object Storage**. There is no file size limit visible to you — simply upload the file. Supported formats include PDF, JPEG, PNG, and Word documents.

### Step 5 — Submit

Click **Submit**. You will receive an on-screen confirmation and an email with your unique case reference number (for example: `INTAKE-2026-000456`).

### Tracking Your Request

Navigate to **My Requests** at any time to see the current status of all your submissions:

| Status | Meaning |
|---|---|
| Pending Review | The Compliance team is reviewing your submission |
| Documents Needed | The Compliance team has asked for additional documents — check your email |
| In Progress | A Compliance Officer is actively working on the KYC report |
| Awaiting Approval | The report is with an approver |
| Approved | KYC is complete — you will receive the report by email |
| Rejected | KYC could not be completed — see the stated reason in the record |

---

## For Compliance Officers: Your Daily Workflow

### Understanding the APEX Workflow Engine

Version 5 uses the **native Oracle APEX Workflow engine** for all approval routing. This means that every time a report moves from one stage to another — submission, approval, RFI, rejection, closure — the system creates a formal workflow task and delivers it to the right person automatically.

You do not need to chase approvers by email. The workflow engine:

- Creates a task in the approver's **Workflow Task Inbox** as soon as you submit a report
- Sends a matching email notification
- Tracks how long each task has been waiting
- Re-routes tasks to a deputy when an approver is on leave

### My Worklist

When you log in, your **Worklist** shows everything that needs your attention, in priority order:

- New intake cases assigned to you
- Reports you have drafted but not yet submitted
- Reports returned to you with a Request for Information (RFI) from an approver
- SLA indicator: colour-coded by how many days remain against your target (green — on track, amber — approaching limit, red — overdue)

### Creating an Entity

Before writing a KYC report, you record the counterparty as an **Entity** in the system.

**Step 1: Duplicate Check**

Type the entity name into the search field. The system searches existing records in real time and displays any close matches. If the counterparty is already in the system, link to the existing record rather than creating a duplicate entry.

**Step 2: Complete the Entity Profile**

The form adapts to the entity type:

- **Individual:** personal details, nationality, date of birth, country of residence
- **Legal entity:** registered name, registration number, country of incorporation, registered address, and the list of Ultimate Beneficial Owners (UBOs) and authorised signatories

**Step 3: Record Screening Results**

After running your sanctions and adverse media screening (WorldCheck or equivalent), return to the entity record and complete the structured screening section:

- Date of screening
- Database(s) used
- Whether a match was returned
- If matched: genuine match or false positive, with supporting rationale
- PEP status
- Summary of findings

!!! warning
    The structured screening fields are a formal compliance record. A regulator or auditor examining this file will rely on these fields, not on free-text notes. Complete them carefully and accurately.

### Creating a KYC Report

Click **New KYC Report** and select the entity you have just created or located. The system pre-populates every field it already knows from the entity record and the original intake form — you will not re-enter data you have already provided.

**Fields you complete:**

- **KYC Type** — Simplified, Ad Hoc, or Enhanced
- **Risk Level** — the system suggests a risk level based on the entity's country tier and screening results; you may override it, but you must record your reason
- **Conclusion** — select a standard conclusion template from the dropdown; the approved template text populates the field and you personalise it as needed
- **Next Steps** — any renewal date, monitoring requirement, or follow-up action

The **SLA indicator** at the top of the report shows the number of days elapsed versus your target completion time.

**Save as Draft** to return to the report later.
**Submit for Approval** when the report is complete and all documents are attached.

When you submit, the APEX Workflow engine automatically:

1. Routes the report to the correct Level 1 approver queue
2. Creates a workflow task in the approver's Task Inbox
3. Sends the approver an email notification
4. Starts the approval SLA timer

### Responding to an RFI

When an approver returns a report to you with a question:

1. A **workflow task** appears in your Task Inbox notification bell (top navigation bar) and you receive an email
2. Go to your Worklist — the report is flagged with an RFI indicator
3. Open the report and read the approver's comment in the **History** tab
4. Make the required changes or upload the requested document
5. Add your response in the comment field
6. Click **Resubmit** — the workflow engine routes it back to the approver automatically

---

## For Approvers: Reviewing Reports

### Your Workflow Task Inbox

In Version 5, your approval queue is driven by the **native APEX Workflow task panel**. Look for the bell icon in the top navigation bar — it shows a count of tasks waiting for your action. Click it to open your **Task Inbox**.

Each task in your inbox shows:

- Report reference and counterparty name
- KYC type and risk level (colour-coded: red — high risk, amber — medium, green — low)
- Submitted by and submission date
- Time pending versus the approval SLA target
- Priority flag where applicable

!!! tip
    The Task Inbox is available on mobile and tablet. If you are away from your desk, you can review and approve low-risk reports directly from your phone.

### Reviewing a Report

Click **Open Task** on any item. The native APEX Workflow task panel opens, containing four tabs:

| Tab | Content |
|---|---|
| **Summary** | All KYC fields, risk assessment, and conclusion |
| **Entity and UBOs** | Entity details, UBO list, and structured screening results for each individual |
| **Documents** | Attached files — documents open inline from OCI Object Storage; no download required for standard viewing |
| **History** | Every action taken on this report — date, user, action taken, and any comments |

Review all four tabs before taking action. The History tab shows you whether this report has been through a previous RFI cycle.

### Taking Action

After your review, scroll to the **Action** section at the bottom of the task panel:

**Approve**

- For low-risk reports: this is the final approval. The report is closed, the requestor receives the completed report by email, and the task is cleared from your inbox.
- For medium and high-risk reports: the report is passed automatically to the Level 2 / MLRO queue. You do not need to do anything further.

**Request For Information (RFI)**

- Select the issue category: Missing Document, Unclear Conclusion, Insufficient Screening Evidence, or Other
- Enter your specific question or instruction
- Click **Send RFI** — the workflow engine routes the report back to the Compliance Officer and creates a task in their worklist

**Reject**

- Enter the reason for rejection (mandatory)
- Click **Reject** — the report is closed; both the Compliance Officer and the original requestor are notified automatically

!!! warning
    A rejection closes the case. If the intent is to have the Compliance Officer correct something and resubmit, use RFI rather than Reject.

### When You Are on Leave

Open your user profile (click your name in the top navigation bar) and set your status to **On Leave**. Your pre-configured deputy will immediately begin receiving your workflow tasks. When you return, set your status back to **Active** — your queue resumes and tasks stop going to your deputy.

!!! note
    The deputy is configured by your KYC system administrator, not by you. If you do not know who your deputy is, or if you need to change them, contact your administrator before you go on leave.

---

## For Level 2 / MLRO Approvers

The Level 2 review process follows the same steps as Level 1 — you receive a workflow task, you review the four-tab panel, and you choose to Approve, issue an RFI, or Reject.

There is one mandatory additional step.

### The SAR Gate

Before you can complete a final approval on any report that reaches Level 2, the system requires you to answer a formal question:

> *"Based on your review of this KYC report, does any information in this file warrant submission of a Suspicious Activity Report (SAR)?"*

- **No** — proceed to approve normally. The report is closed and the requestor is notified.
- **Yes** — the approval is paused. The Head of Compliance and the system administrator are notified immediately. The SAR process is handled separately, outside the KYC system. The KYC report remains open until the SAR outcome is recorded.

!!! warning
    The SAR gate cannot be bypassed. It is a legal control, not a procedural formality. If you are uncertain whether something warrants a SAR, select Yes and seek guidance — you can always record a No outcome once you have taken advice.

---

## For Administrators

### User Management

Navigate to **Administration → User Management** to see all users synchronised from OCI IAM. In Version 5, user provisioning is managed by OCI IAM rather than Oracle IDCS. The experience for administrators is the same: the system imports all active company employees automatically and deactivates leavers.

From the User Management screen you can:

- View all active and inactive users and their assigned KYC roles
- Override a user's KYC role if the default mapping from their job profile is not correct
- Set or change the deputy approver for each approver
- Manually mark an approver as On Leave (activates their deputy immediately)
- View the full delegation log — all occasions when tasks were routed to a deputy

!!! note
    You do not create or delete user records manually. OCI IAM is the authoritative source. New employees appear automatically after their account is provisioned; leavers are deactivated when their OCI IAM account is disabled.

### Reference Data

All configurable lookup values are managed under **Administration → Reference Data**:

- Business Counterparty Categories
- Relationship Types
- Conclusion Templates (organised by risk level and KYC type)
- Country Risk Tiers (FATF classification and internal overrides)
- Document Type Labels
- Report Statuses

Changes to reference data take effect immediately for all new records. Existing records retain the values they were created with.

### Monitoring Dashboard

The **Executive Dashboard** provides real-time KPIs across the entire KYC programme:

| Panel | What It Shows |
|---|---|
| Pipeline Summary | Number of cases at each workflow stage |
| Completed This Month | Count of completed reports and average calendar days to completion |
| SLA Compliance | Percentage of reports completed within the target timeframe |
| Risk Breakdown | Distribution of Low, Medium, and High risk cases (chart) |
| Overdue Cases | All cases that have passed their SLA target, with responsible officer |
| Upcoming Reviews | KYCs due for periodic renewal within the next 60 days |
| Delegation Activity | Cases currently routed to deputies |

!!! tip
    The Executive Dashboard is accessible on a tablet in read-only mode, which is useful for reviewing pipeline status in management meetings.

---

## Frequently Asked Questions

**Q: My login page looks different from before. Has my password changed?**
A: No. The login page now uses OCI IAM instead of the previous Oracle IDCS, so the visual design has changed slightly. Your username and password are the same. If you cannot log in, contact IT support.

**Q: Where do I find reports waiting for my approval?**
A: In Version 5, approvals appear in your **Workflow Task Inbox** — click the bell icon in the top navigation bar. You will also receive an email for each new task.

**Q: I submitted a request and need to add more documents. Can I?**
A: Yes. Go to My Requests, open the relevant record, and use the **Add Document** button. Documents can be added at any stage before final approval.

**Q: My approver is on leave and nothing is happening with my report. What do I do?**
A: The workflow engine automatically routes tasks to the approver's deputy when they are marked as On Leave. If a report has been waiting for more than two working days, contact your KYC system administrator to check the delegation configuration.

**Q: How do I know when my KYC is complete?**
A: You will receive an email with the completed report attached. You can also check the status under My Requests at any time.

**Q: Can I edit a report after I have submitted it for approval?**
A: Not directly. Once submitted, the report is in the approver's workflow queue. The approver can issue an RFI, which returns the report to you for editing. You then resubmit after making the changes.

**Q: Can I use the system on my phone?**
A: Yes. Version 5 uses APEX 24.2 with the Universal Theme 3.0, which is fully responsive. You can also install it as a Progressive Web App (PWA) on iOS or Android by tapping "Add to Home Screen" in your browser. The full workflow — including reviewing reports and approving tasks — works on mobile.

**Q: Where are my uploaded documents stored? Are they secure?**
A: Documents are stored in **OCI Object Storage**, hosted in Oracle's cloud. Access is controlled by the same permissions as the rest of the system — only users with a legitimate role in a case can view its documents. Documents are encrypted at rest and in transit.

**Q: Does this version include any AI features?**
A: No. Version 5 does not include AI-assisted features. AI-driven capabilities are planned for Version 6.

**Q: How long are KYC records retained?**
A: All records are retained for a minimum of five years from the date of approval, in line with Qatari Diar's records retention policy and applicable AML regulations. Records remain searchable and viewable throughout this period.

**Q: Who do I contact if something is not working?**
A: Contact the IT service desk and copy your KYC system administrator. For workflow routing problems (wrong approver, tasks not appearing), contact the KYC administrator directly as these are configuration issues, not technical faults.
