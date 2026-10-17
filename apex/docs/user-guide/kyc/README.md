# KYC user guide

One video per KYC component (screen recordings with captions, no sound), recorded on KYC release 92 with COMMON
release 89. The guide for users, the flow and the rules is `KYC-GUIDE.md`. KYC's shared functions (My Tasks,
documents, e-mail, information requests, users and roles) are COMMON's: their videos are in `../videos/`.

Videos 3 to 5 follow one new request: the requester creates it, the approver checks it and opens the case, the
officer investigates and the manager approves.

| # | Component | Video | Length | Signed in as | Purpose |
|---|---|---|---|---|---|
| 1 | Home | [home.mp4](videos/home.mp4) | 0:40 | REQ1, OFFICER1 | What waits for each user, as tiles and tasks |
| 2 | Parties | [parties.mp4](videos/parties.mp4) | 1:03 | OFFICER1 | Every counterparty once: identity, contacts, owners, documents |
| 3 | KYC Requests: create | [create-request.mp4](videos/create-request.mp4) | 1:55 | REQ1 | The four-step request wizard and Submit |
| 4 | KYC Requests: approval | [request-approval.mp4](videos/request-approval.mp4) | 1:22 | OFFICER1 | The approval screen; the case opens and is assigned |
| 5 | Cases | [cases.mp4](videos/cases.mp4) | 2:46 | OFFICER1, MGR1 | The investigation section by section, then the case approval |
| 6 | KYC Rules | [kyc-rules.mp4](videos/kyc-rules.mp4) | 1:20 | MGR1 | Questionnaires, conclusions, approval matrix, risk model, document rules |
| 7 | Monitoring | [monitoring.mp4](videos/monitoring.mp4) | 0:46 | MGR1 | Review due dates and alerts |
| 8 | Alert Rules | [alert-rules.mp4](videos/alert-rules.mp4) | 0:42 | HOC1 | What the daily monitoring run watches |
| 9 | Executive Dashboard | [dashboard.mp4](videos/dashboard.mp4) | 0:25 | MGR1 | Where KYC stands |

Re-record after a release (KYC and COMMON installed, test users of `apex/tests/test_users.sql`):
`python3 apex/tools/record_kyc_user_guide.py [out dir] [component ...]`.
