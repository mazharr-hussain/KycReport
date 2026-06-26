# KYC Management System — Document Library

**Organisation:** Qatari Diar Real Estate Investment Company  
**Department:** Enterprise Risk Management & Internal Compliance  
**Last Updated:** June 2026

---

## How to Use This Library

Each version of the KYC system has **two documents**:

| Document Type | Audience | Purpose |
|---|---|---|
| **Business Document (BUS)** | Compliance team, management, business stakeholders | Explains what the system does, why, and how it works — in plain language with process flows |
| **Technical Specification (TECH)** | Developers, architects, DBAs, testers | Precise technical detail: schemas, APIs, page specs, security, implementation instructions |

---

## Document Index

### Version 1 — Current System (Built from Source Code)
> The existing JSF web application running on Qatari Diar's servers today.

| # | Document | Audience | File |
|---|---|---|---|
| 1.1 | **Business Overview — Current KYC Application** | Business stakeholders | [V1_BUS_Current_System.md](./V1_BUS_Current_System.md) |
| 1.2 | **Technical Specification — Current JSF System** | Developers / IT team | [V1_TECH_Current_System.md](./V1_TECH_Current_System.md) |

---

### Version 2 — As-Is Business Process (From Requirements Gathering)
> How the compliance team actually works today — manual steps, tools used, workarounds, and pain points captured directly from the Head of Enterprise Risk & Compliance.

| # | Document | Audience | File |
|---|---|---|---|
| 2.1 | **Business Process Guide — Current Way of Working** | Compliance team, management | [V2_BUS_AsIs_Process.md](./V2_AsIs_Process.md) |
| 2.2 | **Functional Requirements — As-Is Process** | Business analysts, developers | [V2_TECH_AsIs_Requirements.md](./V2_TECH_AsIs_Requirements.md) |

---

### Version 3 — Improved Process (Industry Best Practice)
> The redesigned KYC process aligned with FATF 40 Recommendations, Basel KYC Guidelines, and EU 6AMLD. Addresses all identified pain points and compliance gaps.

| # | Document | Audience | File |
|---|---|---|---|
| 3.1 | **Business Process Guide — Best Practice KYC** | Compliance team, management, auditors | [V3_BUS_BestPractice.md](./V3_BUS_BestPractice.md) |
| 3.2 | **System Requirements Specification — Improved KYC** | Developers, solution architects | [V3_TECH_BestPractice_Spec.md](./V3_TECH_BestPractice_Spec.md) |

---

### Version 4 — Oracle APEX Implementation
> The full Oracle APEX solution design — integrated with Oracle Fusion HCM, built on Oracle Database 19c/21c, following APEX 23.2 best practices.

| # | Document | Audience | File |
|---|---|---|---|
| 4.1 | **Business User Guide — APEX KYC System** | All system users (requestors, contributors, approvers, admins) | [V4_BUS_APEX_UserGuide.md](./V4_BUS_APEX_UserGuide.md) |
| 4.2 | **Technical Specification — Oracle APEX Developer Guide** | APEX developers, DBAs, integration architects | [V4_TECH_APEX_Spec.md](./V4_TECH_APEX_Spec.md) |

---

## Supporting Reference Documents

| Document | Description | File |
|---|---|---|
| Compliance Validation Report | Gap analysis against FATF/Basel/EU standards | [../KYC_COMPLIANCE_VALIDATION.md](../KYC_COMPLIANCE_VALIDATION.md) |
| Full Technical Decode | Deep-dive source code analysis of V1 system | [../KYC_TECHNICAL_DOCUMENT.md](../KYC_TECHNICAL_DOCUMENT.md) |
| Process Design Document | V1 and V2 detailed process flows | [../KYC_PROCESS_DESIGN.md](../KYC_PROCESS_DESIGN.md) |
| APEX Architecture Design | Full APEX schema and application design | [../KYC_APEX_DESIGN.md](../KYC_APEX_DESIGN.md) |

---

## Version Progression

```
V1 (Current System)
  → Legacy JSF app, SQL Server, manual email-based workflow
  → No source code available, system stability risk
  → Identified 16 operational pain points

V2 (As-Is Process)
  → How the team actually works: Excel, email, local folders
  → Documented from requirements gathering session
  → Baseline for all future improvement

V3 (Best Practice)
  → Redesigned against FATF/Basel/EU 6AMLD standards
  → Digital intake, structured screening, automated routing
  → KPI framework and ongoing monitoring

V4 (APEX Implementation)
  → Oracle APEX 23.2 on Oracle DB 19c/21c
  → Fusion HCM integration — no manual user management
  → Production-ready technical specification
```

---

## Regulatory Standards Applied

| Standard | Applied In |
|---|---|
| FATF 40 Recommendations (2023) | V2, V3, V4 |
| Basel Committee KYC Guidelines | V2, V3, V4 |
| EU 6th Anti-Money Laundering Directive (6AMLD) | V3, V4 |
| ISO 31000 Risk Management | V3, V4 |
| Oracle APEX Security Best Practices | V4 |
| Oracle Fusion Integration Standards | V4 |
