# Intake & Document Validation Flow

Covers Phase 0 (Request Intake) and Phase 1 (Document Validation) of the KYC process.

!!! tip "How to edit this diagram"
    1. Go to [diagrams.net](https://app.diagrams.net)
    2. Open via **File → Open from → GitHub**
    3. Navigate to `docs/diagrams/drawio/intake-flow.drawio`
    4. Edit visually and save — it commits directly to GitHub
    5. Netlify rebuilds and this page updates automatically

![Intake and Document Validation](drawio/intake-flow.drawio)

> **Version note:** The diagram shows Jaro-Winkler fuzzy matching for duplicate detection (V3–V5). In V6, this step is performed by AI Vector Search (cosine similarity) instead — see [V6 Technical Spec](../V6_TECH_APEX26AI_Spec.md) Section 4.

---

## KPI Note

!!! important "KPI Clock Start Point"

    The turnaround time SLA is measured from `docs_complete_date` — the moment the compliance officer confirms all documents are present and correct.

    It is **not** measured from when the department first sent their email or submitted the form. The compliance team cannot be held accountable for delays in the department providing documentation.

    | KYC Type | SLA Target |
    |---|---|
    | Simplified | 5 business days |
    | AdHoc | 10 business days |
    | Enhanced | 20 business days |
