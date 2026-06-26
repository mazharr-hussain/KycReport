---
tags:
  - V1
  - Current System
  - Technical
  - JSF
  - SQL Server
---

# V1 — Current System Technical Specification

!!! danger "Security Defects — Immediate Action Required"

    **TD-01:** Passwords stored in plain text in the `Login` table.  
    **TD-02:** SMTP password stored in plain text in `KycConfig.properties`.

    These must be remediated before deploying any replacement system.

--8<-- "docs/V1_TECH_Current_System.md"
