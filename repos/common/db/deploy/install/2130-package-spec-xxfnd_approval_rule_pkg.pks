
create or replace package xxfnd_approval_rule_pkg authid definer as
    -- Registers (or renames) a transaction type and its attributes ('CODE=Name[=LOOKUP_TYPE]' items).
    procedure register_type(p_type in varchar2, p_application_code in varchar2, p_name in varchar2,
                            p_description in varchar2 default null, p_attributes in apex_t_varchar2 default null);
    -- The rule a transaction matches. p_attributes: 'CODE=value' items.
    function matching_rule(p_type in varchar2, p_attributes in apex_t_varchar2) return number;
    -- Release 76 (A-11): why a transaction could not start its approval, or null. No matching rule (XXFND_APPROVAL_NO_RULE),
    -- or a step of the matching rule that nobody can approve: no active user holds its role (XXFND_APPROVAL_NO_APPROVER).
    -- A component calls it on Submit, so the user gets the message instead of a workflow that faults later.
    function approval_error(p_type in varchar2, p_attributes in apex_t_varchar2) return varchar2;
    -- Starts the approval of a transaction: copies the matching rule's approvers; returns the rule name.
    -- A transaction already started is started again (a resubmitted request). Release 76: a rule without steps is the
    -- deliberate "no approval" rule - the approval is complete at once (STEP_COUNT = 0, the component approves it);
    -- APPROVAL_ERROR is raised as an error.
    function start_approval(p_type in varchar2, p_txn_id in varchar2, p_attributes in apex_t_varchar2,
                            p_requester in varchar2) return varchar2;
    -- Y while the transaction has an approval in progress.
    function is_started(p_type in varchar2, p_txn_id in varchar2) return varchar2;
    -- The step whose turn it is: its name, and its approvers (comma-separated user names).
    function current_step_name(p_type in varchar2, p_txn_id in varchar2) return varchar2;
    function current_approvers(p_type in varchar2, p_txn_id in varchar2) return varchar2;
    -- Role of the current step (null for a user / requester step).
    function current_role(p_type in varchar2, p_txn_id in varchar2) return varchar2;
    -- Position (1, 2, ...) and number of steps.
    function current_position(p_type in varchar2, p_txn_id in varchar2) return number;
    function step_count(p_type in varchar2, p_txn_id in varchar2) return number;
    -- Moves to the next approver: Y when there is one, N when the approval is complete.
    function next_step(p_type in varchar2, p_txn_id in varchar2) return varchar2;
    -- Ad-hoc approver after the current step (p_position NEXT) or at the end (END). Allowed to the requester and
    -- the current approvers (p_force Y: the component checked it).
    procedure add_approver(p_type in varchar2, p_txn_id in varchar2, p_approver_type in varchar2,
                           p_role_code in varchar2 default null, p_user_name in varchar2 default null,
                           p_position in varchar2 default 'NEXT', p_comment in varchar2 default null,
                           p_force in varchar2 default 'N');
    procedure cancel(p_type in varchar2, p_txn_id in varchar2);

    -- Release 82: the one task decision every application calls (no copies of the APEX task calls on pages).
    -- p_decision: APPROVE | REJECT | REQUEST_INFO | SUBMIT_INFO | ADD_APPROVER | COMMENT. A comment (p_comment) is
    -- recorded on the task first for APPROVE, REJECT, ADD_APPROVER and COMMENT; it is the question for REQUEST_INFO
    -- and the answer for SUBMIT_INFO. ADD_APPROVER adds p_add_user after the current approver of p_approval_type /
    -- p_txn_id. Returns Y when done; N for REQUEST_INFO when the task cannot ask its initiator (the approver is the
    -- initiator): the application then returns the record to its requester in its own way.
    function decide_task(p_task_id       in number,
                         p_decision      in varchar2,
                         p_comment       in varchar2 default null,
                         p_approval_type in varchar2 default null,
                         p_txn_id        in varchar2 default null,
                         p_add_user      in varchar2 default null) return varchar2;
    -- The approvers of a transaction in order, with their state (DONE, CURRENT, WAITING); before its approval
    -- started, the matching rule's approvers (state EXPECTED) for the attributes given.
    function steps(p_type in varchar2, p_txn_id in varchar2, p_attributes in apex_t_varchar2 default null)
        return xxfnd_approval_step_tab pipelined;
    -- Release 76 (F-05): the number of approvals in progress started from a rule (the rule screen's impact preview; a
    -- count only, whatever the administrator's data security on the transactions).
    function open_count(p_rule_id in number) return number;
    -- Release 94: Y for an approver type in use; N for a placeholder type (needs the HCM data, not available yet).
    function approver_type_available(p_approver_type in varchar2) return varchar2;
    -- Release 94: the due date of the current step when its rule step has a deadline (DUE_DAYS), else null (the
    -- process deadline of Workflow Setup > Deadlines and Escalation applies).
    function step_due_date(p_type in varchar2, p_txn_id in varchar2) return timestamp with time zone;
    -- Display name of an approver (role name, user name or "Requester").
    function approver_label(p_approver_type in varchar2, p_role_code in varchar2, p_user_name in varchar2) return varchar2;
    -- Release 86: an application's default rule for one of its transaction types (REGISTER_TYPE), added only while the
    -- type has no rule at all (afterwards the administrators own the rules). P_CONDITIONS: 'ATTRIBUTE=value' items;
    -- P_STEPS in order: 'Step name=ROLE=role code', 'Step name=USER=user name' or 'Step name=REQUESTER' (no step = no
    -- approval). ORA-20180 / ORA-20186 as every registration; ORA-20187 for an unknown type; ORA-20188 for a step
    -- that is not well formed.
    procedure register_default_rule(p_application_code in varchar2,
                                    p_type             in varchar2,
                                    p_rule_name        in varchar2,
                                    p_steps            in apex_t_varchar2 default null,
                                    p_conditions       in apex_t_varchar2 default null,
                                    p_priority         in number   default 100,
                                    p_description      in varchar2 default null);
    -- Release 88 (C10): one more rule of an application's type (several rules per type: different conditions or
    -- priorities), added only while the type has no rule of that name (a rule the administrators changed is kept).
    -- Same parameters and errors as REGISTER_DEFAULT_RULE; the type must belong to P_APPLICATION_CODE.
    procedure register_rule(p_application_code in varchar2,
                            p_type             in varchar2,
                            p_rule_name        in varchar2,
                            p_steps            in apex_t_varchar2 default null,
                            p_conditions       in apex_t_varchar2 default null,
                            p_priority         in number   default 100,
                            p_description      in varchar2 default null);
    -- Release 88 (C8, C9): removes what the application registered (its own rows only, through
    -- XXFND_APPLICATION_PKG.REMOVE_REGISTERED: ORA-20187 not registered, ORA-20186 another application's, ORA-20196 in use).
    procedure unregister_rule(p_application_code in varchar2, p_type in varchar2, p_rule_name in varchar2);
    -- the type with its rules (refused while a transaction of the type exists: in use)
    procedure unregister_type(p_application_code in varchar2, p_type in varchar2);
    procedure unregister_application(p_application_code in varchar2);
    -- Release 113: approval groups of a process (approval type) - a named set of approvers; a rule level of approver type
    -- GROUP names the group code (in ROLE_CODE). The type must belong to P_APPLICATION_CODE (ORA-20186 otherwise).
    procedure save_group(p_application_code in varchar2,
                         p_type             in varchar2,
                         p_group_code       in varchar2,
                         p_group_name       in varchar2,
                         p_description      in varchar2 default null,
                         p_enabled_flag     in varchar2 default 'Y');
    -- the members: P_ROLES and P_USERS colon-separated (as a shuttle gives them); members not listed are removed
    procedure set_group_members(p_application_code in varchar2, p_group_code in varchar2,
                                p_roles in varchar2, p_users in varchar2);
    -- refused (ORA-20537) while a rule level names the group
    procedure delete_group(p_application_code in varchar2, p_group_code in varchar2);
    -- the users of a group (its users and the active users of its roles), comma-separated
    function group_users(p_group_code in varchar2) return varchar2;
end xxfnd_approval_rule_pkg;
/
