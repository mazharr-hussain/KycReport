create or replace force editionable view xxcus.xxfnd_config_changes_v (
    detail_pk,
    change_type,
    change_title,
    change_summary,
    submitted_by,
    submitted_date
) as
    select
        'XXCMP_QUESTIONS:' || q.question_id detail_pk,
        'Risk scoring answers'              change_type,
        q.questionnaire_code
        || ' / '
        || substr(q.question_text, 1, 200)  change_title,
        listagg(nvl(ao.answer_label, ao.lookup_code)
                || ': '
                || ao.risk_points
                || ' points'
                ||
                case
                    when ao.critical_flag = 'Y' then
                        ', critical'
                end
                ||
                case
                    when ao.waiver_qualifying_flag = 'Y' then
                        ', waiver'
                end,
                '; ') within group(
        order by
            ao.display_sequence
        )                                   change_summary,
        max(ao.last_updated_by)             submitted_by,
        max(ao.last_update_date)            submitted_date
    from
             xxcmp_answer_options ao
        join xxcmp_questions q on q.question_id = ao.question_id
    where
        ao.approval_status = 'PENDING_APPROVAL'
    group by
        q.question_id,
        q.questionnaire_code,
        q.question_text
    union all
    select
        'XXCMP_ATTACHMENT_RULES:' || r.attachment_rule_id,
        'Mandatory document rule',
        r.entity_name
        || ' / '
        || r.category_code,
        nvl(r.jurisdiction, 'any jurisdiction')
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
        r.last_update_date
    from
        xxcmp_attachment_rules r
    where
        r.approval_status = 'PENDING_APPROVAL'
    union all
    select
        'XXFND_INTEGRATION_PURPOSES:' || p.purpose_code,
        'Integration purpose',
        p.purpose_name,
        p.capture_method
        || ' / '
        || nvl(p.endpoint_code, 'no endpoint'),
        p.last_updated_by,
        p.last_update_date
    from
        xxfnd_integration_purposes p
    where
        p.approval_status = 'PENDING_APPROVAL';


-- sqlcl_snapshot {"hash":"0b51527e29ead30326aed95bc4b15e47bfc7b4d2","type":"VIEW","name":"XXFND_CONFIG_CHANGES_V","schemaName":"XXCUS","sxml":""}