create or replace force editionable view xxcus.xxcmp_party_contacts_dfv (
    party_contact_id,
    context_code
) as
    select
        t.party_contact_id,
        t.attribute_category context_code
    from
        xxcmp_party_contacts t;


-- sqlcl_snapshot {"hash":"096fd134b79c0097d542b454f09f3104d8a6c786","type":"VIEW","name":"XXCMP_PARTY_CONTACTS_DFV","schemaName":"XXCUS","sxml":""}