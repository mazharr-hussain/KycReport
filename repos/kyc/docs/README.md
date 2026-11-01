# KYC Compliance Platform (app 134) - requirements summary

KYC (schema XXCUS, APEX app 134) runs counterparty KYC: requests from departments, the KYC case, parties, monitoring
and rules. It uses COMMON (app 135) as it is for security, setup, workflow, documents and notifications. Each
component's detail is in `components/<component>/requirements.md`, next to its technical document and (to be written)
its training material. State: KYC 105.

This file is synced to the README of the GitHub Project "KYC Application" on every merge to main.

## Components

| Component | Purpose | Documents |
|---|---|---|
| Alert Rules | The rules that raise monitoring alerts on approved counterparties. | [requirements](components/alert-rules/requirements.md) · [technical](components/alert-rules/technical.md) |
| Case Assignment | Who may give a KYC case to a Compliance officer. | [requirements](components/case-assignment/requirements.md) · [technical](components/case-assignment/technical.md) |
| Cases | The KYC investigation of a counterparty, from opening to approval. | [requirements](components/cases/requirements.md) · [technical](components/cases/technical.md) |
| Dashboard | The executive view of KYC activity. | [requirements](components/dashboard/requirements.md) · [technical](components/dashboard/technical.md) |
| Home | The KYC landing page. | [requirements](components/home/requirements.md) · [technical](components/home/technical.md) |
| Kyc Requests | Requesting departments ask for KYC on a counterparty. | [requirements](components/kyc-requests/requirements.md) · [technical](components/kyc-requests/technical.md) |
| Kyc Rules | The rules behind KYC decisions. | [requirements](components/kyc-rules/requirements.md) · [technical](components/kyc-rules/technical.md) |
| Monitoring | Ongoing monitoring of approved counterparties. | [requirements](components/monitoring/requirements.md) · [technical](components/monitoring/technical.md) |
| Parties | The counterparty master (organisations and individuals). | [requirements](components/parties/requirements.md) · [technical](components/parties/technical.md) |

## Agreed changes (backlog)

The KYC changes agreed for later (L1 pipeline, request stage gaps, new screening questions, question display types, one approval process per component, the `APP_USER` scheme) are on the "KYC Application" board.
