create or replace force editionable view xxcus.xxcmp_party_relationships_dfv (
    party_relationship_id,
    context_code
) as
    select
        t.party_relationship_id,
        t.attribute_category context_code
    from
        xxcmp_party_relationships t;


-- sqlcl_snapshot {"hash":"cc299249ef21f97160fdd29ee62077460e5776d4","type":"VIEW","name":"XXCMP_PARTY_RELATIONSHIPS_DFV","schemaName":"XXCUS","sxml":""}