create or replace force editionable view xxcus.xxfnd_pending_approvals_v (
    table_name,
    change_type,
    pk_value,
    change_summary,
    submitted_by,
    submitted_date,
    approval_status
) as
    select
        'XXCMP_ANSWER_OPTIONS'       table_name,
        'Risk scoring answer'        change_type,
        to_char(ao.answer_option_id) pk_value,
        q.questionnaire_code
        || ' / '
        || substr(q.question_text, 1, 120)
        || ' / '
        || nvl(ao.answer_label, ao.lookup_code)
        || ' / points '
        || ao.risk_points
        ||
        case
            when ao.critical_flag = 'Y' then
                    ' / critical'
        end
        ||
        case
            when ao.waiver_qualifying_flag = 'Y' then
                    ' / waiver'
        end
        change_summary,
        ao.last_updated_by           submitted_by,
        ao.last_update_date          submitted_date,
        ao.approval_status
    from
             xxcmp_answer_options ao
        join xxcmp_questions q on q.question_id = ao.question_id
    where
        ao.approval_status = 'PENDING_APPROVAL'
    union all
    select
        'XXCMP_ATTACHMENT_RULES',
        'Mandatory document rule',
        to_char(r.attachment_rule_id),
        r.entity_name
        || ' / '
        || r.category_code
        || ' / '
        || nvl(r.jurisdiction, 'any jurisdiction')
        || ' / '
        || nvl(r.entity_type, 'any entity type')
        || ' / '
        ||
        case r.mandatory_flag
                when 'Y' then
                    'mandatory'
                else
                    'optional'
        end,
        r.last_updated_by,
        r.last_update_date,
        r.approval_status
    from
        xxcmp_attachment_rules r
    where
        r.approval_status = 'PENDING_APPROVAL'
    union all
    select
        'XXFND_INTEGRATION_PURPOSES',
        'Integration purpose',
        p.purpose_code,
        p.purpose_name
        || ' / '
        || p.capture_method
        || ' / '
        || nvl(p.endpoint_code, 'no endpoint'),
        p.last_updated_by,
        p.last_update_date,
        p.approval_status
    from
        xxfnd_integration_purposes p
    where
        p.approval_status = 'PENDING_APPROVAL';


-- sqlcl_snapshot {"hash":"d56b7465c6739d2f331e3129d04cdaeb415db9b1","type":"VIEW","name":"XXFND_PENDING_APPROVALS_V","schemaName":"XXCUS","sxml":""}