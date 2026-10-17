# parties

Feature of KYC Compliance Platform. Copied as it is from the current application (no change).

## Uses (objects of these features are named in its files)
cases, common:attachments, common:data-security, common:flexfields, common:integrations, common:lookups, common:roles-privileges, common:users-access, kyc-requests, kyc-rules, monitoring

## Used by
cases, kyc-requests, kyc-rules, monitoring

## Files
- `db/packages/xxcmp_party_pkg.sql`
- `db/sequences/xxcmp_party_number_s.sql`
- `db/tables/xxcmp_parties.sql`
- `db/tables/xxcmp_party_contacts.sql`
- `db/tables/xxcmp_party_id_verifications.sql`
- `db/tables/xxcmp_party_relationships.sql`
- `db/triggers/xxcmp_parties_num.sql`
- `db/triggers/xxcmp_party_rel_cycle.sql`
- `pages/p00020-parties.apx`
- `pages/p00021-party.apx`
- `pages/p00022-party-contact.apx`
- `pages/p00023-party-relationship.apx`
- `pages/p00024-party-details.apx`
- `pages/p00025-party-details-step.apx`
- `pages/p00026-id-verification.apx`
- `pages/p00027-registry-check.apx`
- `shared-components/authorizations.apx`
- `shared-components/lists.apx`
- `shared-components/lovs.apx`
- `tests/party_test.sql`
- `tests/party_ui.py`
- `tests/r74_party_test.sql`
- `tests/r74_party_ui.py`
