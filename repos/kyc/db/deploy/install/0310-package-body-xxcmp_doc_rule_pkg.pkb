
create or replace package body xxcmp_doc_rule_pkg as

    function mandatory_categories(p_entity_name  in varchar2,
                                  p_jurisdiction in varchar2,
                                  p_entity_type  in varchar2) return apex_t_varchar2 is
        l_result apex_t_varchar2;
    begin
        select category_code bulk collect into l_result
          from (select r.category_code, r.mandatory_flag,
                       row_number() over (partition by r.category_code
                                          order by case when r.jurisdiction is not null then 0 else 1 end
                                                 + case when r.entity_type  is not null then 0 else 1 end,
                                                   case when r.jurisdiction is not null then 0 else 1 end,
                                                   r.priority) rn
                  from xxcmp_attachment_rules r
                 where r.entity_name = p_entity_name
                   and r.enabled_flag = 'Y'
                   and r.approval_status = 'APPROVED'
                   and (r.jurisdiction is null or r.jurisdiction = p_jurisdiction)
                   and (r.entity_type  is null or r.entity_type  = p_entity_type))
         where rn = 1 and mandatory_flag = 'Y'
         order by category_code;
        return l_result;
    end mandatory_categories;

    function missing_categories(p_entity_name  in varchar2,
                                p_pk1_value    in varchar2,
                                p_jurisdiction in varchar2,
                                p_entity_type  in varchar2) return apex_t_varchar2 is
        l_required apex_t_varchar2 := mandatory_categories(p_entity_name, p_jurisdiction, p_entity_type);
        l_missing  apex_t_varchar2 := apex_t_varchar2();
        l_count    pls_integer;
    begin
        for i in 1 .. l_required.count loop
            select count(*) into l_count
              from xxfnd_attached_documents_v v
             where v.entity_name = p_entity_name
               and v.pk1_value   = p_pk1_value
               and v.category_code = l_required(i)
               and v.expired_flag = 'N'
               and (v.upload_status in ('STORED','NOT_APPLICABLE'));
            if l_count = 0 then
                l_missing.extend;
                l_missing(l_missing.count) := l_required(i);
            end if;
        end loop;
        return l_missing;
    end missing_categories;

end xxcmp_doc_rule_pkg;
/
