
-- Every party with an approved case, as of its latest approved case.
create or replace view xxcmp_watchlist_v as
with latest as (
    select c.*,
           row_number() over (partition by c.party_id order by c.closed_date desc nulls last, c.case_id desc) as rn
      from xxcmp_cases c
     where c.case_status = 'APPROVED'
), lead_days as (
    -- release 91: the KYC setting REVIEW_LEAD_DAYS (XXCMP_CASE_PKG.PARAMETER)
    select xxcmp_case_pkg.parameter('REVIEW_LEAD_DAYS', 30) as days from dual
), open_review as (
    select r.party_id, max(r.request_id) as request_id, max(r.request_number) as request_number
      from xxcmp_requests r
     where r.request_type <> 'NEW_ONBOARDING'
       and r.request_status in ('DRAFT','IN_PROGRESS','INFO_NEEDED')
     group by r.party_id
)
select p.party_id,
       p.party_number,
       p.party_name,
       p.party_type,
       p.jurisdiction,
       l.case_id,
       l.case_number,
       l.risk_tier,
       l.pep_flag,
       l.enhanced_kyc_flag,
       cast(l.closed_date as date) as approved_date,
       l.next_review_date,
       l.next_review_date - trunc(sysdate) as days_to_review,
       case when l.next_review_date < trunc(sysdate)                  then 'OVERDUE'
            when o.request_id is not null                             then 'IN_REVIEW'
            when l.next_review_date - trunc(sysdate) <= d.days        then 'DUE'
            else 'CURRENT' end as review_status,
       o.request_id as review_request_id,
       o.request_number as review_request_number,
       (select count(*) from xxcmp_alerts a where a.party_id = p.party_id and a.alert_status = 'OPEN') as open_alerts
  from latest l
  join xxcmp_parties p on p.party_id = l.party_id
  left join open_review o on o.party_id = l.party_id
 cross join lead_days d
 where l.rn = 1;
