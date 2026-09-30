create or replace force editionable view xxcus.xxfnd_user_roles_v (
    user_role_id,
    employee_id,
    user_name,
    full_name,
    source_type,
    role_code,
    role_name,
    application_code,
    start_date_active,
    end_date_active,
    enabled_flag,
    active_flag
) as
    select
        ur.user_role_id,
        ur.employee_id,
        e.user_name,
        e.full_name,
        e.source_type,
        ur.role_code,
        r.role_name,
        r.application_code,
        ur.start_date_active,
        ur.end_date_active,
        ur.enabled_flag,
        case
            when ur.enabled_flag = 'Y'
                 and r.enabled_flag = 'Y'
                 and e.enabled_flag = 'Y'
                 and trunc(sysdate) between ur.start_date_active and nvl(ur.end_date_active,
                                                                         trunc(sysdate))
                 and trunc(sysdate) between e.start_date_active and nvl(e.end_date_active,
                                                                        trunc(sysdate)) then
                'Y'
            else
                'N'
        end active_flag
    from
             xxfnd_user_roles ur
        join xxfnd_employees e on e.employee_id = ur.employee_id
        join xxfnd_roles     r on r.role_code = ur.role_code;


-- sqlcl_snapshot {"hash":"f860c462966b12f3135d539395c3cc71604a62f2","type":"VIEW","name":"XXFND_USER_ROLES_V","schemaName":"XXCUS","sxml":""}