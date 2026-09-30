create or replace package xxcus.xxcmp_monitor_pkg authid definer as

    -- Daily run (APEX Automation "KYC monitoring"): periodic reviews, then the alert rules.
    procedure run_daily;
    -- Starts a periodic review for every party whose review falls due within the lead days. Returns how many.
    function start_periodic_reviews return number;
    -- Evaluates every enabled alert rule. Returns the number of new alerts.
    function run_alerts return number;

    -- Early reassessment of an approved case (Monitoring Watchlist); null when allowed.
    function early_review_error (
        p_case_id in number
    ) return varchar2;

    function trigger_early_review (
        p_case_id  in number,
        p_reason   in varchar2,
        p_alert_id in number default null,
        p_source   in varchar2 default 'MANUAL'
    ) return number;

    procedure acknowledge (
        p_alert_id in number
    );

end xxcmp_monitor_pkg;
/


-- sqlcl_snapshot {"hash":"d37d1acf2a591a61919aea312ffb816e091b3f7b","type":"PACKAGE_SPEC","name":"XXCMP_MONITOR_PKG","schemaName":"XXCUS","sxml":""}