create or replace force editionable view xxcus.xxcmp_parties_dfv (
    party_id,
    context_code
) as
    select
        t.party_id,
        t.attribute_category context_code
    from
        xxcmp_parties t;


-- sqlcl_snapshot {"hash":"0dfc72bdb660f6f64a9a72e71142e7483aa66188","type":"VIEW","name":"XXCMP_PARTIES_DFV","schemaName":"XXCUS","sxml":""}