comment on table xxcus.xxcmp_parties is
    'Every company or individual the organization deals with. Shared master data: Intake links to it, Investigation enriches it.';

comment on column xxcus.xxcmp_parties.data_provenance is
    'REGISTRY_VERIFIED once confirmed against an official registry (integration purpose REGISTRY_LOOKUP).';

comment on column xxcus.xxcmp_parties.id_number is
    'Individuals: identity document number, used for duplicate checks.';

comment on column xxcus.xxcmp_parties.id_type is
    'Individuals: identity document type (lookup ID_DOCUMENT_TYPE).';

comment on column xxcus.xxcmp_parties.party_number is
    'Human-readable number, e.g. P-000123, assigned by trigger.';


-- sqlcl_snapshot {"hash":"98b336c6820b79feb92879f7972cbdee67b5671c","type":"COMMENT","name":"xxcmp_parties","schemaName":"xxcus","sxml":""}