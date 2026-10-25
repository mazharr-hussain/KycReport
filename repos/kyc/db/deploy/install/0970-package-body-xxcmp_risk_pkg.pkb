
create or replace package body xxcmp_risk_pkg as

    type t_line is record (factor_code varchar2(30), factor_name varchar2(200), detail varchar2(1000), points number,
                           force_tier varchar2(30));
    type t_lines is table of t_line;

    c_tier_order constant varchar2(100) := ':LOW:MEDIUM:HIGH:';

    function tier_rank(p_tier in varchar2) return number is
    begin
        return nvl(instr(c_tier_order, ':' || p_tier || ':'), 0);
    end tier_rank;

    -- the factor as the model sees it (approved or proposed values); null points = not in the model
    procedure factor(p_code in varchar2, p_model in varchar2, p_name out varchar2, p_points out number,
                     p_force out varchar2, p_type out varchar2) is
    begin
        select max(factor_name), max(factor_type),
               max(case when p_model = 'PROPOSED' then case when enabled_flag = 'Y' then points end
                        else case when approved_enabled_flag = 'Y' then approved_points end end),
               max(case when p_model = 'PROPOSED' then case when enabled_flag = 'Y' then force_tier end
                        else case when approved_enabled_flag = 'Y' then approved_force_tier end end)
          into p_name, p_type, p_points, p_force
          from xxcmp_risk_factors where factor_code = p_code;
    end factor;

    function on_list(p_list in varchar2, p_country in varchar2, p_model in varchar2) return boolean is
        l_n pls_integer;
    begin
        select count(*) into l_n from xxcmp_risk_countries
         where list_code = p_list and country_code = p_country
           and case when p_model = 'PROPOSED' then enabled_flag else approved_enabled_flag end = 'Y';
        return l_n > 0;
    end on_list;

    function lines(p_case_id in number, p_model in varchar2) return t_lines is
        l_lines   t_lines := t_lines();
        l_case    xxcmp_cases%rowtype;
        l_country xxcmp_parties.jurisdiction%type;
        l_score   number;
        l_n       pls_integer;

        procedure add(p_code in varchar2, p_detail in varchar2, p_base in number default null) is
            l_name   varchar2(200);
            l_points number;
            l_force  varchar2(30);
            l_type   varchar2(30);
        begin
            factor(p_code, p_model, l_name, l_points, l_force, l_type);
            if l_points is not null or l_force is not null then
                l_lines.extend;
                l_lines(l_lines.count).factor_code := p_code;
                l_lines(l_lines.count).factor_name := l_name;
                l_lines(l_lines.count).detail      := p_detail;
                l_lines(l_lines.count).points      := case when l_type = 'SCORE' then round(nvl(p_base, 0) * nvl(l_points, 0) / 100, 1)
                                                            else nvl(l_points, 0) end;
                l_lines(l_lines.count).force_tier  := l_force;
            end if;
        end add;
    begin
        xxfnd_vpd_pkg.begin_trusted;     -- the model reads the case, its request, party, screenings and owners
        select * into l_case from xxcmp_cases where case_id = p_case_id;
        select max(jurisdiction) into l_country from xxcmp_parties where party_id = l_case.party_id;
        select max(intake_score) into l_score from xxcmp_requests where request_id = l_case.request_id;
        if l_score is not null then
            add('QUESTIONNAIRE', 'Questionnaire score ' || l_score, l_score);
        end if;
        if on_list('FATF_BLACK', l_country, p_model) then
            add('COUNTRY_FATF_BLACK', 'Country ' || xxfnd_lookup_pkg.lookup_meaning('JURISDICTION', l_country) || ' (FATF black list)');
        elsif on_list('FATF_GREY', l_country, p_model) then
            add('COUNTRY_FATF_GREY', 'Country ' || xxfnd_lookup_pkg.lookup_meaning('JURISDICTION', l_country) || ' (FATF grey list)');
        end if;
        if on_list('INTERNAL', l_country, p_model) then
            add('COUNTRY_INTERNAL', 'Country ' || xxfnd_lookup_pkg.lookup_meaning('JURISDICTION', l_country) || ' (company list)');
        end if;
        if l_case.pep_flag = 'Y' then
            add('PEP', 'Politically exposed person');
        end if;
        select count(*) into l_n from xxcmp_screenings
         where case_id = p_case_id and match_status = 'CONFIRMED_MATCH' and sanctions_flag = 'Y';
        if l_n > 0 then
            add('SANCTIONS_MATCH', 'Confirmed sanctions match');
        end if;
        select count(*) into l_n from xxcmp_screenings where case_id = p_case_id and match_status = 'POTENTIAL_MATCH';
        if l_n > 0 then
            add('SCREENING_POTENTIAL', l_n || ' potential screening match(es) not resolved');
        end if;
        select count(*) into l_n from xxcmp_screenings where case_id = p_case_id and adverse_media_flag = 'Y';
        if l_n > 0 then
            add('ADVERSE_MEDIA', 'Adverse media found');
        end if;
        -- an owner or officer from a FATF-listed country
        select count(*) into l_n
          from xxcmp_party_relationships r
          join xxcmp_parties o on o.party_id = r.subject_party_id
         where r.object_party_id = l_case.party_id and (r.end_date is null or r.end_date >= trunc(sysdate))
           and exists (select 1 from xxcmp_risk_countries c
                        where c.country_code = o.jurisdiction and c.list_code in ('FATF_BLACK', 'FATF_GREY')
                          and case when p_model = 'PROPOSED' then c.enabled_flag else c.approved_enabled_flag end = 'Y');
        if l_n > 0 then
            add('OWNER_HIGH_RISK_COUNTRY', l_n || ' owner(s) or officer(s) from a FATF-listed country');
        end if;
        xxfnd_vpd_pkg.end_trusted;
        return l_lines;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end lines;

    function total(p_lines in t_lines) return number is
        l_sum number := 0;
    begin
        for i in 1 .. p_lines.count loop
            l_sum := l_sum + nvl(p_lines(i).points, 0);
        end loop;
        return l_sum;
    end total;

    function tier_of(p_lines in t_lines, p_model in varchar2) return varchar2 is
        l_score number := total(p_lines);
        l_tier  varchar2(30);
    begin
        select max(risk_tier) keep (dense_rank last order by case when p_model = 'PROPOSED' then min_score else approved_min_score end)
          into l_tier
          from xxcmp_risk_tiers
         where case when p_model = 'PROPOSED' then min_score else approved_min_score end <= l_score;
        for i in 1 .. p_lines.count loop
            if tier_rank(p_lines(i).force_tier) > tier_rank(l_tier) then
                l_tier := p_lines(i).force_tier;
            end if;
        end loop;
        return l_tier;
    end tier_of;

    function breakdown_json(p_case_id in number, p_model in varchar2 default 'APPROVED') return clob is
        l_lines t_lines := lines(p_case_id, p_model);
        l_rows  json_array_t := json_array_t();
        l_row   json_object_t;
    begin
        for i in 1 .. l_lines.count loop
            l_row := json_object_t();
            l_row.put('factor_code', l_lines(i).factor_code);
            l_row.put('factor_name', l_lines(i).factor_name);
            l_row.put('detail', l_lines(i).detail);
            l_row.put('points', l_lines(i).points);
            l_row.put('force_tier', l_lines(i).force_tier);
            l_rows.append(l_row);
        end loop;
        return l_rows.to_clob;
    end breakdown_json;

    function score(p_case_id in number, p_model in varchar2 default 'APPROVED') return number is
    begin
        return total(lines(p_case_id, p_model));
    end score;

    function suggested_tier(p_case_id in number, p_model in varchar2 default 'APPROVED') return varchar2 is
    begin
        return tier_of(lines(p_case_id, p_model), p_model);
    end suggested_tier;

    procedure calculate(p_case_id in number) is
        l_lines t_lines := lines(p_case_id, c_approved);
    begin
        delete from xxcmp_case_risk_scores where case_id = p_case_id;
        for i in 1 .. l_lines.count loop
            insert into xxcmp_case_risk_scores (case_id, factor_code, detail, points, force_tier, calculated_by)
            values (p_case_id, l_lines(i).factor_code, l_lines(i).detail, l_lines(i).points, l_lines(i).force_tier,
                    xxfnd_util_pkg.current_user);
        end loop;
    end calculate;

    function review_months(p_risk_tier in varchar2) return number is
        l_months number;
    begin
        select max(approved_review_months) into l_months from xxcmp_risk_tiers where risk_tier = p_risk_tier;
        if l_months is null then
            select max(to_number(tag default null on conversion error)) into l_months
              from xxfnd_lookup_values where lookup_type = 'RISK_TIER' and lookup_code = p_risk_tier;
        end if;
        return l_months;
    end review_months;

    function impact_json return clob is
        l_rows  json_array_t := json_array_t();
        l_row   json_object_t;
        l_cur   t_lines;
        l_new   t_lines;
        l_ct    varchar2(30);
        l_nt    varchar2(30);
    begin
        xxfnd_vpd_pkg.begin_trusted;
        for c in (select k.case_id, k.case_number, p.party_name
                    from xxcmp_cases k join xxcmp_parties p on p.party_id = k.party_id
                   where k.case_status in ('INVESTIGATION', 'PENDING_APPROVAL', 'PENDING_INFORMATION')) loop
            l_cur := lines(c.case_id, c_approved);
            l_new := lines(c.case_id, c_proposed);
            l_ct  := tier_of(l_cur, c_approved);
            l_nt  := tier_of(l_new, c_proposed);
            if nvl(l_ct, '#') <> nvl(l_nt, '#') or total(l_cur) <> total(l_new) then
                l_row := json_object_t();
                l_row.put('case_id', c.case_id);
                l_row.put('case_number', c.case_number);
                l_row.put('party_name', c.party_name);
                l_row.put('current_score', total(l_cur));
                l_row.put('current_tier', l_ct);
                l_row.put('proposed_score', total(l_new));
                l_row.put('proposed_tier', l_nt);
                l_rows.append(l_row);
            end if;
        end loop;
        xxfnd_vpd_pkg.end_trusted;
        return l_rows.to_clob;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end impact_json;

    function has_pending_changes return varchar2 is
        l_n pls_integer;
    begin
        select count(*) into l_n from (
            select approval_status from xxcmp_risk_factors union all
            select approval_status from xxcmp_risk_countries union all
            select approval_status from xxcmp_risk_tiers)
         where approval_status <> 'APPROVED';
        return case when l_n > 0 then 'Y' else 'N' end;
    end has_pending_changes;

    procedure submit_changes is
        l_n pls_integer;
    begin
        for u in (select 'XXCMP_RISK_FACTOR_SET' unit, 'XXCMP_RISK_FACTORS' tab from dual
                  union all select 'XXCMP_RISK_COUNTRY_SET', 'XXCMP_RISK_COUNTRIES' from dual
                  union all select 'XXCMP_RISK_TIER_SET', 'XXCMP_RISK_TIERS' from dual) loop
            execute immediate 'select count(*) from ' || u.tab || ' where approval_status in (''DRAFT'', ''REJECTED'', ''PENDING_APPROVAL'')'
                into l_n;
            if l_n > 0 then
                xxfnd_approval_pkg.request(u.unit, 'KYC');
            end if;
        end loop;
    end submit_changes;

end xxcmp_risk_pkg;
/
