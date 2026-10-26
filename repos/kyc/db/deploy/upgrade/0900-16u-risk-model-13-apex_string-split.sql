
-- the starting model (approved at install, only when missing): current behaviour is unchanged - the model only
-- suggests a tier; the review intervals are today's (RISK_TIER lookup)
declare
    procedure f(p_code in varchar2, p_name in varchar2, p_type in varchar2, p_points in number, p_force in varchar2,
                p_seq in number, p_desc in varchar2) is
    begin
        merge into xxcmp_risk_factors t using (select p_code factor_code from dual) s
           on (t.factor_code = s.factor_code)
         when not matched then insert (factor_code, factor_name, factor_type, points, force_tier, display_sequence, description,
                                       approval_status)
                               values (p_code, p_name, p_type, p_points, p_force, p_seq, p_desc, 'APPROVED');
    end f;
    procedure c(p_list in varchar2, p_countries in varchar2, p_source in varchar2) is
    begin
        for x in (select trim(column_value) code from table(apex_string.split(p_countries, ','))) loop
            merge into xxcmp_risk_countries t using (select p_list list_code, x.code country_code from dual) s
               on (t.list_code = s.list_code and t.country_code = s.country_code)
             when not matched then insert (list_code, country_code, source_reference, approval_status)
                                   values (s.list_code, s.country_code, p_source, 'APPROVED');
        end loop;
    end c;
    procedure t(p_tier in varchar2, p_min in number) is
        l_months number;
    begin
        select nvl(max(to_number(tag default null on conversion error)), 12) into l_months
          from xxfnd_lookup_values where lookup_type = 'RISK_TIER' and lookup_code = p_tier;
        merge into xxcmp_risk_tiers r using (select p_tier risk_tier from dual) s
           on (r.risk_tier = s.risk_tier)
         when not matched then insert (risk_tier, min_score, review_months, approval_status)
                               values (p_tier, p_min, l_months, 'APPROVED');
    end t;
begin
    xxfnd_util_pkg.set_install_mode(true);
    f('QUESTIONNAIRE', 'Questionnaire score', 'SCORE', 100, null, 10, 'The requester''s questionnaire score, at this percentage.');
    f('COUNTRY_FATF_BLACK', 'Country on the FATF black list', 'FLAG', 60, 'HIGH', 20, 'The party''s country is a high-risk jurisdiction subject to a call for action.');
    f('COUNTRY_FATF_GREY', 'Country on the FATF grey list', 'FLAG', 25, null, 30, 'The party''s country is under increased monitoring.');
    f('COUNTRY_INTERNAL', 'Country on the company list', 'FLAG', 15, null, 40, 'The party''s country is on the company''s own high-risk list.');
    f('PEP', 'Politically exposed person', 'FLAG', 30, null, 50, 'The case concerns a politically exposed person.');
    f('SANCTIONS_MATCH', 'Confirmed sanctions match', 'FLAG', 60, 'HIGH', 60, 'A screening confirmed a sanctions match.');
    f('SCREENING_POTENTIAL', 'Unresolved potential match', 'FLAG', 20, null, 70, 'A screening found a potential match not yet resolved.');
    f('ADVERSE_MEDIA', 'Adverse media', 'FLAG', 20, null, 80, 'A screening found adverse media.');
    f('OWNER_HIGH_RISK_COUNTRY', 'Owner from a FATF-listed country', 'FLAG', 15, null, 90, 'An owner or officer is from a country on a FATF list.');
    -- FATF lists as published by the FATF (plenary of June 2025; Compliance updates them after each plenary)
    c('FATF_BLACK', 'KP,IR,MM', 'FATF high-risk jurisdictions subject to a call for action, June 2025');
    c('FATF_GREY', 'DZ,AO,BO,BG,BF,CM,CI,HR,CD,HT,KE,LA,LB,MC,MZ,NA,NP,NG,ZA,SS,SY,VE,VN,VG,YE',
      'FATF jurisdictions under increased monitoring, June 2025');
    t('LOW', 0);
    t('MEDIUM', 30);
    t('HIGH', 60);
    commit;
    xxfnd_util_pkg.set_install_mode(false);
exception
    when others then
        xxfnd_util_pkg.set_install_mode(false);
        raise;
end;
/
