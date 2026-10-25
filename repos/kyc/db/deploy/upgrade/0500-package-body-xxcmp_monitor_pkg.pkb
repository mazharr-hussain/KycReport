
create or replace package body xxcmp_monitor_pkg as

    function open_review(p_party_id in number) return varchar2 is
        l_number xxcmp_requests.request_number%type;
    begin
        select max(request_number) into l_number
          from xxcmp_requests
         where party_id = p_party_id
           and request_status in ('DRAFT','IN_PROGRESS','INFO_NEEDED');
        return l_number;
    end open_review;

    -- Closes the party's open alerts, linking them to the review that answers them.
    procedure close_alerts(p_party_id in number, p_request_id in number) is
    begin
        update xxcmp_alerts
           set alert_status = 'CLOSED', review_request_id = nvl(review_request_id, p_request_id)
         where party_id = p_party_id and alert_status in ('OPEN','ACKNOWLEDGED');
    end close_alerts;

    function early_review_error(p_case_id in number) return varchar2 is
        l_case  xxcmp_cases%rowtype;
        l_open  varchar2(30);
    begin
        select * into l_case from xxcmp_cases where case_id = p_case_id;
        if l_case.case_status <> 'APPROVED' then
            return 'Only an approved case can be reassessed.';
        end if;
        l_open := open_review(l_case.party_id);
        if l_open is not null then
            return 'Request ' || l_open || ' for this party is already in progress.';
        end if;
        return null;
    exception
        when no_data_found then
            return 'Case not found.';
    end early_review_error;

    function trigger_early_review(p_case_id in number, p_reason in varchar2, p_alert_id in number default null,
                                  p_source in varchar2 default 'MANUAL') return number is
        l_error varchar2(4000) := early_review_error(p_case_id);
        l_req   number;
        l_party number;
    begin
        if l_error is not null then
            raise_application_error(-20701, l_error);
        end if;
        if trim(p_reason) is null then
            raise_application_error(-20702, 'Give the reason for the early reassessment.');
        end if;
        xxfnd_vpd_pkg.begin_trusted;
        select party_id into l_party from xxcmp_cases where case_id = p_case_id;
        l_req := xxcmp_request_pkg.start_review(p_case_id, 'EVENT_TRIGGERED_REVIEW', p_source, p_reason);
        if p_alert_id is not null then
            update xxcmp_alerts set review_request_id = l_req where alert_id = p_alert_id;
        end if;
        close_alerts(l_party, l_req);
        xxfnd_vpd_pkg.end_trusted;
        return l_req;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end trigger_early_review;

    procedure acknowledge(p_alert_id in number) is
    begin
        update xxcmp_alerts
           set alert_status = 'ACKNOWLEDGED', acknowledged_by = xxfnd_util_pkg.current_user,
               acknowledged_date = systimestamp
         where alert_id = p_alert_id and alert_status = 'OPEN';
    end acknowledge;

    function start_periodic_reviews return number is
        l_count pls_integer := 0;
        l_req   number;
    begin
        for w in (select case_id, party_id, next_review_date from xxcmp_watchlist_v
                   where review_status in ('DUE','OVERDUE') and review_request_id is null) loop
            begin
                l_req := xxcmp_request_pkg.start_review(w.case_id, 'PERIODIC_REVIEW', 'SCHEDULED',
                             'Periodic review due ' || to_char(w.next_review_date, 'DD-Mon-YYYY') || '.');
                close_alerts(w.party_id, l_req);
                l_count := l_count + 1;
            exception
                when others then
                    -- one party must not stop the others; the error is kept in the APEX debug log
                    apex_debug.error('Periodic review for case %s failed: %s', w.case_id, sqlerrm);
            end;
        end loop;
        return l_count;
    end start_periodic_reviews;

    function run_alerts return number is
        l_new   pls_integer := 0;
        l_id    number;
        l_req   number;

        procedure raise_alert(p_rule in xxcmp_alert_rules%rowtype, p_key in varchar2, p_party in number,
                              p_case in number, p_message in varchar2, p_due in date, p_review in boolean) is
            l_tokens json_object_t := json_object_t();
            l_url    varchar2(4000);
        begin
            insert into xxcmp_alerts (alert_rule_id, alert_key, party_id, case_id, alert_message, due_date)
            values (p_rule.alert_rule_id, p_key, p_party, p_case, substr(p_message, 1, 1000), p_due)
            returning alert_id into l_id;
            l_new := l_new + 1;
            if p_rule.notify_flag = 'Y' and p_rule.recipient_role_code is not null then
                begin
                    begin
                        l_url := apex_page.get_url(p_page => 221, p_plain_url => true);
                    exception
                        when others then l_url := null;   -- no APEX session
                    end;
                    l_tokens.put('ALERT_NAME', apex_escape.html(p_rule.rule_name));
                    l_tokens.put('ALERT_MESSAGE', apex_escape.html(p_message));
                    l_tokens.put('LINK', l_url);
                    xxfnd_notify_pkg.send_to_users('KYC_ALERT', xxfnd_workflow_pkg.users_in_role(p_rule.recipient_role_code),
                                                   l_tokens.to_clob);
                exception
                    when others then
                        -- the alert stands even when the e-mail cannot be sent
                        apex_debug.error('Alert %s: e-mail not sent: %s', l_id, sqlerrm);
                end;
            end if;
            if p_review and p_rule.start_review_flag = 'Y' and p_case is not null
               and early_review_error(p_case) is null then
                l_req := trigger_early_review(p_case, 'Automatic: ' || p_message, l_id, 'EVENT_DRIVEN');
            end if;
        exception
            when dup_val_on_index then
                null;   -- already raised for this subject
        end raise_alert;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        -- Alerts whose subject has moved on: superseded case, closed investigation.
        update xxcmp_alerts a
           set a.alert_status = 'CLOSED'
         where a.alert_status in ('OPEN','ACKNOWLEDGED')
           and a.case_id is not null
           and not exists (select 1 from xxcmp_watchlist_v w where w.case_id = a.case_id)
           and not exists (select 1 from xxcmp_cases c where c.case_id = a.case_id
                            and c.case_status in ('INVESTIGATION','PENDING_APPROVAL','PENDING_INFORMATION'));

        for r in (select * from xxcmp_alert_rules where enabled_flag = 'Y' order by rule_code) loop
            begin
                if r.alert_type = 'REVIEW_DUE' then
                    for w in (select * from xxcmp_watchlist_v
                               where next_review_date between trunc(sysdate) and trunc(sysdate) + r.days_before
                                 and review_request_id is null   -- a review is already running
                                 and (r.risk_tier is null or risk_tier = r.risk_tier)) loop
                        raise_alert(r, 'CASE:' || w.case_id || ':' || to_char(w.next_review_date, 'YYYYMMDD'), w.party_id, w.case_id,
                                    w.party_name || ': review due on ' || to_char(w.next_review_date, 'DD-Mon-YYYY')
                                    || ' (' || w.case_number || ').', w.next_review_date, false);
                    end loop;
                elsif r.alert_type = 'REVIEW_OVERDUE' then
                    for w in (select * from xxcmp_watchlist_v
                               where next_review_date + r.days_before < trunc(sysdate)
                                 and (r.risk_tier is null or risk_tier = r.risk_tier)) loop
                        raise_alert(r, 'CASE:' || w.case_id || ':' || to_char(w.next_review_date, 'YYYYMMDD'), w.party_id, w.case_id,
                                    w.party_name || ': review overdue since ' || to_char(w.next_review_date, 'DD-Mon-YYYY')
                                    || nvl2(w.review_request_number, ' (review ' || w.review_request_number || ' in progress).', '.'),
                                    w.next_review_date, false);
                    end loop;
                elsif r.alert_type = 'SLA_BREACH' then
                    for c in (select c.case_id, c.case_number, c.party_id, c.sla_due_date, p.party_name
                                from xxcmp_cases c join xxcmp_parties p on p.party_id = c.party_id
                               where c.case_status = 'INVESTIGATION'
                                 and c.sla_due_date + r.days_before < trunc(sysdate)
                                 and (r.risk_tier is null or c.risk_tier = r.risk_tier)) loop
                        raise_alert(r, 'CASE:' || c.case_id, c.party_id, c.case_id,
                                    c.case_number || ' (' || c.party_name || '): investigation past its SLA of '
                                    || to_char(c.sla_due_date, 'DD-Mon-YYYY') || '.', c.sla_due_date, false);
                    end loop;
                elsif r.alert_type = 'DOCUMENT_EXPIRY' then
                    for d in (select w.party_id, w.case_id, w.party_name, a.attached_document_id, a.title,
                                     a.category_name, a.expiry_date
                                from xxcmp_watchlist_v w
                                join xxfnd_attached_documents_v a
                                  on a.entity_name = 'XXCMP_PARTIES' and a.pk1_value = to_char(w.party_id)
                               where a.expiry_date <= trunc(sysdate) + r.days_before
                                 and (r.risk_tier is null or w.risk_tier = r.risk_tier)) loop
                        raise_alert(r, 'DOC:' || d.attached_document_id || ':' || to_char(d.expiry_date, 'YYYYMMDD'),
                                    d.party_id, d.case_id,
                                    d.party_name || ': ' || nvl(d.category_name, d.title)
                                    || case when d.expiry_date < trunc(sysdate) then ' expired on ' else ' expires on ' end
                                    || to_char(d.expiry_date, 'DD-Mon-YYYY') || '.',
                                    d.expiry_date, d.expiry_date < trunc(sysdate));
                    end loop;
                elsif r.alert_type = 'ADVERSE_SCREENING' then
                    -- a screening recorded after the party was approved that is not clean
                    for s in (select w.party_id, w.case_id, w.party_name, s.screening_id, s.screened_date,
                                     xxfnd_lookup_pkg.lookup_meaning('SCREENING_TYPE', s.screening_type) as check_type,
                                     xxfnd_lookup_pkg.lookup_meaning('SCREENING_MATCH_STATUS', s.match_status) as result
                                from xxcmp_watchlist_v w
                                join xxcmp_screenings s on s.party_id = w.party_id
                               where s.creation_date > w.approved_date
                                 and (s.match_status in ('POTENTIAL_MATCH','CONFIRMED_MATCH')
                                      or 'Y' in (s.pep_flag, s.sanctions_flag, s.adverse_media_flag))
                                 and (r.risk_tier is null or w.risk_tier = r.risk_tier)) loop
                        raise_alert(r, 'SCREENING:' || s.screening_id, s.party_id, s.case_id,
                                    s.party_name || ': ' || s.check_type || ' - ' || s.result || ' on '
                                    || to_char(s.screened_date, 'DD-Mon-YYYY') || '.', s.screened_date, true);
                    end loop;
                end if;
            exception
                when others then
                    apex_debug.error('Alert rule %s failed: %s', r.rule_code, sqlerrm);
            end;
        end loop;
        xxfnd_vpd_pkg.end_trusted;
        return l_new;
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end run_alerts;

    procedure run_daily is
        l_reviews number;
        l_alerts  number;
    begin
        xxfnd_vpd_pkg.begin_trusted;
        l_reviews := start_periodic_reviews;
        l_alerts  := run_alerts;
        xxfnd_vpd_pkg.end_trusted;
        apex_debug.info('KYC monitoring: %s periodic review(s) started, %s new alert(s).', l_reviews, l_alerts);
    exception
        when others then
            xxfnd_vpd_pkg.end_trusted;
            raise;
    end run_daily;

end xxcmp_monitor_pkg;
/
