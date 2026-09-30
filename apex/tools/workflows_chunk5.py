#!/usr/bin/env python3
"""Chunk 5 APEX workflows (shared-components/workflows): KYC_REQUEST (intake) and KYC_CASE (investigation
and approval). Activities call XXCMP_REQUEST_PKG / XXCMP_CASE_PKG; human steps are the task definitions
DOC_CHECKLIST_REVIEW, CASE_INVESTIGATION and CASE_APPROVAL."""
import json, os

OUT = os.path.join(os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'src', 'database', 'xxcus', 'apex_apps', 'f101'), 'shared-components', 'workflows')
os.makedirs(OUT, exist_ok=True)


def diagram(x, y, z):
    return json.dumps({"position": {"x": x, "y": y}, "z": z}, separators=(',', ':'))


def conn(name, to, when=None, value=None, seq=None):
    cond = ''
    if when is not None:
        cond = f'''                condition {{
                    when: {when}
                }}
'''
    if value is not None:
        cond = f'''                execution {{
                    sequence: {seq or 10}
                }}
                condition {{
                    operator: =
                    value: {value}
                }}
'''
    return f'''            connection (
                name: {name}
{cond}                activity {{
                    to: @{to}
                }}
            )
'''


def act(ident, name, typ, seq, x, y, body='', conns=()):
    return f'''        activity {ident} (
            name: {name}
            type: {typ}
{body}            layout {{
                sequence: {seq}
            }}
            advanced {{
                diagram: {diagram(x, y, seq)}
            }}
{''.join(chr(10) + c for c in conns)}
        )

'''


def code(plsql):
    return f'''            source {{
                plsqlCode: {plsql}
            }}
'''


def task(definition, task_var, outcome_var=None, owner_var=None):
    res = ''
    if outcome_var:
        res = f'''            result {{
                outcome: {outcome_var}{f"""
                owner: {owner_var}""" if owner_var else ''}
            }}
'''
    return f'''            humanTask {{
                definition: @{definition}
                taskIdItem: {task_var}
                detailsPkItem: APEX$WORKFLOW_DETAIL_PK
            }}
{res}'''


def switch_fn(plsql):
    return f'''            condition {{
                conditionType: functionBody
                plsqlFunctionBody: {plsql}
            }}
'''


def switch_var(var):
    return f'''            switch {{
                type: checkWorkflowVar
            }}
            compare {{
                compareVar: {var}
            }}
'''


def variable(ident, label):
    return f'''        variable {ident} (
            label {{
                label: {label}
            }}
        )

'''


ADMIN = '''        participant (
            name: Workflow administrators
            type: admin
            value {
                type: expression
                plsqlExpression: xxfnd_task_pkg.business_admins
            }
        )
'''


def version(number, state, activities, variables):
    return f'''    version {number} (
        settings {{
            state: {state}
        }}

{''.join(activities)}{''.join(variables)}{ADMIN}
    )

'''


def workflow(static, name, title, comment, activities, variables, versions=None):
    """versions: [(number, state, activities, variables)]; default one active version 1.0."""
    versions = versions or [('1.0', 'active', activities, variables)]
    return f'''workflow {static} (
    name: {name}
    title: {title}
    comments {{
        comments: {comment}
    }}

{''.join(version(*v) for v in versions)})
'''


# KYC_REQUEST ------------------------------------------------------------------
req = [
    act('Start', 'Start', 'workflowStart', 10, 60, 200, conns=[conn('Evaluate', 'Evaluate')]),
    act('Evaluate', 'Evaluate intake', 'executeCode', 20, 200, 180,
        code('xxcmp_request_pkg.evaluate(:APEX$WORKFLOW_DETAIL_PK);'), [conn('Next', 'KycRequired')]),
    act('KycRequired', 'KYC required?', 'switch', 30, 380, 180,
        switch_fn("return xxcmp_request_pkg.outcome(:APEX$WORKFLOW_DETAIL_PK) = 'ASSIGNED';"),
        [conn('Yes', 'ChecklistReview', when='true'), conn('No', 'CloseRequest', when='false')]),
    act('CloseRequest', 'Close request (not required / auto-approved)', 'executeCode', 40, 380, 360,
        code('xxcmp_request_pkg.close_without_case(:APEX$WORKFLOW_DETAIL_PK);'), [conn('Done', 'End')]),
    act('ChecklistReview', 'Document checklist review', 'humanTaskCreate', 50, 560, 180,
        task('DOC_CHECKLIST_REVIEW', 'V_CHECKLIST_TASK_ID', 'V_CHECKLIST_OUTCOME', 'V_CHECKLIST_REVIEWER'),
        [conn('Decided', 'ChecklistOutcome')]),
    act('ChecklistOutcome', 'Documents complete?', 'switch', 60, 760, 180, switch_var('V_CHECKLIST_OUTCOME'),
        [conn('Approved', 'OpenCase', value='APPROVED', seq=10), conn('Rejected', 'RejectRequest', value='REJECTED', seq=20)]),
    act('OpenCase', 'Open case', 'executeCode', 70, 960, 120,
        code('xxcmp_request_pkg.create_case(:APEX$WORKFLOW_DETAIL_PK);'), [conn('Done', 'End')]),
    act('RejectRequest', 'Reject request', 'executeCode', 80, 960, 260,
        code('xxcmp_request_pkg.reject(:APEX$WORKFLOW_DETAIL_PK);'), [conn('Done', 'End')]),
    act('End', 'End', 'workflowEnd', 90, 1160, 200),
]
# 1.1: a new counterparty that resembles existing parties is decided by Compliance before the checklist
req11 = [
    act('Start', 'Start', 'workflowStart', 10, 60, 200, conns=[conn('Evaluate', 'Evaluate')]),
    act('Evaluate', 'Evaluate intake', 'executeCode', 20, 200, 180,
        code('xxcmp_request_pkg.evaluate(:APEX$WORKFLOW_DETAIL_PK);'), [conn('Next', 'KycRequired')]),
    act('KycRequired', 'KYC required?', 'switch', 30, 380, 180,
        switch_fn("return xxcmp_request_pkg.outcome(:APEX$WORKFLOW_DETAIL_PK) = 'ASSIGNED';"),
        [conn('Yes', 'CounterpartyPending', when='true'), conn('No', 'CloseRequest', when='false')]),
    act('CloseRequest', 'Close request (not required / auto-approved)', 'executeCode', 40, 380, 360,
        code('xxcmp_request_pkg.close_without_case(:APEX$WORKFLOW_DETAIL_PK);'), [conn('Done', 'End')]),
    act('CounterpartyPending', 'Counterparty to decide?', 'switch', 45, 480, 60,
        switch_fn("return xxcmp_request_pkg.match_pending(:APEX$WORKFLOW_DETAIL_PK) = 'Y';"),
        [conn('Yes', 'CounterpartyMatch', when='true'), conn('No', 'ChecklistReview', when='false')]),
    act('CounterpartyMatch', 'Counterparty match (Compliance)', 'humanTaskCreate', 47, 560, 0,
        task('COUNTERPARTY_MATCH', 'V_MATCH_TASK_ID'), [conn('Decided', 'ChecklistReview')]),
    act('ChecklistReview', 'Document checklist review', 'humanTaskCreate', 50, 640, 180,
        task('DOC_CHECKLIST_REVIEW', 'V_CHECKLIST_TASK_ID', 'V_CHECKLIST_OUTCOME', 'V_CHECKLIST_REVIEWER'),
        [conn('Decided', 'ChecklistOutcome')]),
    act('ChecklistOutcome', 'Documents complete?', 'switch', 60, 820, 180, switch_var('V_CHECKLIST_OUTCOME'),
        [conn('Approved', 'OpenCase', value='APPROVED', seq=10), conn('Rejected', 'RejectRequest', value='REJECTED', seq=20)]),
    act('OpenCase', 'Open case', 'executeCode', 70, 1000, 120,
        code('xxcmp_request_pkg.create_case(:APEX$WORKFLOW_DETAIL_PK);'), [conn('Done', 'End')]),
    act('RejectRequest', 'Reject request', 'executeCode', 80, 1000, 260,
        code('xxcmp_request_pkg.reject(:APEX$WORKFLOW_DETAIL_PK);'), [conn('Done', 'End')]),
    act('End', 'End', 'workflowEnd', 90, 1200, 200),
]
req_vars = [variable('V_CHECKLIST_TASK_ID', 'Checklist task'), variable('V_CHECKLIST_OUTCOME', 'Checklist outcome'),
            variable('V_CHECKLIST_REVIEWER', 'Checklist reviewer')]
with open(os.path.join(OUT, 'KYC-REQUEST.apx'), 'w') as f:
    f.write(workflow('KYC_REQUEST', 'KYC Request', 'KYC request &APEX$WORKFLOW_DETAIL_PK.',
                     'Module 1 intake: evaluate the answers (link the chosen party, or hold a new counterparty that '
                     'resembles existing parties for Compliance; score, gate and critical answers), close the request when '
                     'KYC is not required or auto-approved, otherwise Compliance reviews the documents - deciding a possible '
                     'duplicate counterparty in the same review task - and opens the case (KYC_CASE workflow). Versions 1.0 '
                     'and 1.1 remain for requests started on them.',
                     None, None,
                     versions=[('1.0', 'inactive', req, req_vars),
                               ('1.1', 'inactive', req11, req_vars + [variable('V_MATCH_TASK_ID', 'Counterparty match task')]),
                               # 1.2: the counterparty match is decided inside the checklist review task
                               ('1.2', 'active', req, req_vars)]))

# KYC_CASE ---------------------------------------------------------------------
case = [
    act('Start', 'Start', 'workflowStart', 10, 60, 200, conns=[conn('Investigate', 'Investigate')]),
    act('Investigate', 'Investigation', 'humanTaskCreate', 20, 200, 180,
        task('CASE_INVESTIGATION', 'V_INVESTIGATION_TASK_ID'), [conn('Submitted', 'StartApproval')]),
    act('StartApproval', 'Start approval', 'executeCode', 30, 400, 180,
        code('xxcmp_case_pkg.start_approval(:APEX$WORKFLOW_DETAIL_PK);'), [conn('Level 1', 'Level1')]),
    act('Level1', 'Approval level 1', 'humanTaskCreate', 40, 600, 180,
        task('CASE_APPROVAL', 'V_LEVEL1_TASK_ID', 'V_LEVEL1_OUTCOME', 'V_LEVEL1_APPROVER'), [conn('Decided', 'Level1Outcome')]),
    act('Level1Outcome', 'Level 1 approved?', 'switch', 50, 800, 180, switch_var('V_LEVEL1_OUTCOME'),
        [conn('Approved', 'MoreLevels', value='APPROVED', seq=10), conn('Rejected', 'RejectCase', value='REJECTED', seq=20)]),
    act('MoreLevels', 'Second level required?', 'switch', 60, 1000, 120,
        switch_fn("return xxcmp_case_pkg.has_next_level(:APEX$WORKFLOW_DETAIL_PK) = 'Y';"),
        [conn('Yes', 'Level2', when='true'), conn('No', 'ApproveCase', when='false')]),
    act('Level2', 'Approval level 2', 'humanTaskCreate', 70, 1200, 60,
        task('CASE_APPROVAL', 'V_LEVEL2_TASK_ID', 'V_LEVEL2_OUTCOME', 'V_LEVEL2_APPROVER'), [conn('Decided', 'Level2Outcome')]),
    act('Level2Outcome', 'Level 2 approved?', 'switch', 80, 1400, 60, switch_var('V_LEVEL2_OUTCOME'),
        [conn('Approved', 'ApproveCase', value='APPROVED', seq=10), conn('Rejected', 'RejectCase', value='REJECTED', seq=20)]),
    act('ApproveCase', 'Approve and close case', 'executeCode', 90, 1400, 200,
        code('xxcmp_case_pkg.approve_case(:APEX$WORKFLOW_DETAIL_PK);'), [conn('Done', 'End')]),
    act('RejectCase', 'Reject and close case', 'executeCode', 100, 1000, 320,
        code('xxcmp_case_pkg.reject_case(:APEX$WORKFLOW_DETAIL_PK);'), [conn('Done', 'End')]),
    act('End', 'End', 'workflowEnd', 110, 1600, 200),
]
with open(os.path.join(OUT, 'KYC-CASE.apx'), 'w') as f:
    f.write(workflow('KYC_CASE', 'KYC Case', 'KYC case &APEX$WORKFLOW_DETAIL_PK.',
                     'Module 2: investigation by the officer, then one or two approval levels from the approval matrix '
                     '(risk tier; Enhanced KYC needs two); approval or rejection closes the case and completes the request.',
                     case, [variable('V_INVESTIGATION_TASK_ID', 'Investigation task'),
                            variable('V_LEVEL1_TASK_ID', 'Level 1 task'), variable('V_LEVEL1_OUTCOME', 'Level 1 outcome'),
                            variable('V_LEVEL1_APPROVER', 'Level 1 approver'),
                            variable('V_LEVEL2_TASK_ID', 'Level 2 task'), variable('V_LEVEL2_OUTCOME', 'Level 2 outcome'),
                            variable('V_LEVEL2_APPROVER', 'Level 2 approver')]))
print('workflows written')
