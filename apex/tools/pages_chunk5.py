#!/usr/bin/env python3
"""Chunk 5 pages: KYC Requests (200-205) and Cases (210-216), from reusable patterns.

200 KYC Requests         list; data security decides which requests a user sees
201-203 Create Request   wizard: counterparty, questionnaire, review and submit
205 KYC Request          request, stage, answers, documents; DOC_CHECKLIST_REVIEW task page
210 Cases                workbench with SLA status; Create Case
211 Case                 Case 360: investigation, officer questionnaire, screenings, documents, UBO,
                         notes, RFIs, decisions, workflow; CASE_INVESTIGATION task page
212 Case Decision        CASE_APPROVAL task page: SAR, conditions, next review, approve/reject
213 Screening, 214 Beneficial Owner, 215 Document Verification, 216 Create Case  (drawers)
"""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from pagegen import col, item, list_page, form_page, ir_region, refresh_da, breadcrumb_region, fn_validation

from pagekit import *  # noqa: F401,F403 (shared page building blocks)

REQ_LIST_SQL = '''select q.*,
       apex_page.get_url(p_page => 205, p_items => 'P205_REQUEST_ID', p_values => to_char(q.request_id), p_clear_cache => '205') as open_url,
       case when q.request_status = 'DRAFT' and upper(q.requester_user_name) = upper(:APP_USER)
            then apex_page.get_url(p_page => 201, p_items => 'P201_REQUEST_ID', p_values => to_char(q.request_id), p_clear_cache => '201,202,203')
       end as edit_url,
       case when q.request_status = 'DRAFT' and upper(q.requester_user_name) = upper(:APP_USER) then 'Edit' end as edit
  from (
        select r.request_id,
               r.request_number,
               r.party_name,
               xxfnd_util_pkg.lookup_meaning('KYC_REQUEST_TYPE', r.request_type) as request_type,
               xxcmp_request_pkg.stage(r.request_id) as stage,
               xxfnd_util_pkg.lookup_meaning('KYC_INTAKE_OUTCOME', r.intake_outcome) as intake_outcome,
               r.intake_score,
               xxfnd_util_pkg.lookup_meaning('REQUESTING_DEPARTMENT', r.requesting_department) as department,
               r.requester_user_name,
               r.request_status,
               r.submitted_date,
               (select c.case_number from xxcmp_cases c where c.request_id = r.request_id) as case_number
          from xxcmp_requests r
       ) q'''
write('p00200-kyc-requests.apx', list_page(
    200, 'KYC Requests', 'KYC-REQUESTS', 'kyc',
    'KYC requests you may see: your own, or all of them for the Compliance team. Create Request starts a new one.',
    REQ_LIST_SQL,
    [col('REQUEST_ID', 'Request Id', 10, kind='hidden', dtype='NUMBER', pk=True),
     col('REQUEST_NUMBER', 'Request', 20, link='OPEN_URL'),
     col('PARTY_NAME', 'Counterparty', 30),
     col('REQUEST_TYPE', 'Type', 40),
     col('STAGE', 'Stage', 50),
     col('INTAKE_OUTCOME', 'Intake Outcome', 60),
     col('INTAKE_SCORE', 'Intake Score', 70, dtype='NUMBER'),
     col('DEPARTMENT', 'Department', 80),
     col('REQUESTER_USER_NAME', 'Requested By', 90),
     col('SUBMITTED_DATE', 'Submitted', 100, dtype='DATE', fmt='SINCE'),
     col('CASE_NUMBER', 'Case', 110),
     col('EDIT', 'Edit', 115, link='EDIT_URL'),
     col('OPEN_URL', 'Open Url', 120, kind='hidden'),
     col('EDIT_URL', 'Edit Url', 125, kind='hidden'),
     col('REQUEST_STATUS', 'Status Code', 130, kind='hidden')],
    create_label='Create Request', form_page=201))

# ===================================================================== 201
p = 201
t = page_header(p, 'Create Request - Counterparty', 'CREATE-REQUEST', 'kyc',
                'Step 1 of 3: who is the counterparty. Choose it from the existing parties, or enter a new one with its '
                'contact details (the other details are optional): the system then looks for parties that may be the same '
                '(name, registration or identity number, date of incorporation or birth, country). A counterparty with the '
                'same registration number and country as an existing party must use that party. Compliance decides at the '
                'checklist review whether a similar party is the same. Save as Draft keeps the request to finish later.')
t += breadcrumb_region('Create Request') + '\n'
t += wizard_region()
t += static_region('counterparty', 'Counterparty', 20)
t += static_region('new_party', 'New Counterparty', 30)
t += static_region('buttons', 'Buttons', 90, template='buttons-container')
t += pitem(p, 'REQUEST_ID', 'hidden', None, 1, 'counterparty', protect=True)
t += pitem(p, 'PARTY_TYPE', 'radioGroup', 'Counterparty Type', 10, 'counterparty', required=True,
           lov=lookup_lov('PARTY_TYPE', None), default='ORGANIZATION',
           help_text='An organisation (company, trust, government entity) or an individual.')
t += pitem(p, 'PARTY_SELECTION', 'radioGroup', 'Counterparty', 20, 'counterparty', required=True,
           lov=('sql', "select 'Existing counterparty' as display_value, 'EXISTING' as return_value from dual\n"
                       "union all select 'New counterparty', 'NEW' from dual", None), default='NEW',
           help_text='Existing: the counterparty is already a party (choose it). New: not yet known to the organisation.')
t += pitem(p, 'PARTY_ID', 'popupLov', 'Existing Counterparty', 30, 'counterparty', mark_required=True,
           lov=('sql', """select j.party_name || ' (' || j.party_number || nvl2(j.country, ', ' || j.country, null) || ')' as display_value,
       j.party_id as return_value
  from json_table(xxcmp_request_pkg.party_directory_json(:P201_PARTY_TYPE), '$[*]'
         columns (party_id number path '$.party_id', party_number varchar2(30) path '$.party_number',
                  party_name varchar2(360) path '$.party_name', country varchar2(240) path '$.country')) j
 order by j.party_name""", None),
           help_text='Search by name or party number.')
t = t.replace('''    pageItem P201_PARTY_ID (
        type: popupLov''', '''    pageItem P201_PARTY_ID (
        type: popupLov''')
# the party list depends on the type
i = t.index('    pageItem P201_PARTY_ID (')
j = t.index('        layout {', i)
t = t[:j] + '''        cascadingLov {
            parentItems: P201_PARTY_TYPE
        }
''' + t[j:]
ORG_ITEMS = 'P201_REGISTRATION_NUMBER,P201_ENTITY_TYPE,P201_INCORPORATION_DATE'
PERSON_ITEMS = 'P201_DATE_OF_BIRTH,P201_NATIONALITY,P201_ID_TYPE,P201_ID_NUMBER'
t += pitem(p, 'PARTY_NAME', 'textField', 'Name', 10, 'new_party', mark_required=True, max_len=360,
           help_text='Legal name of the organisation, or full name of the individual.')
t += pitem(p, 'REGISTRATION_NUMBER', 'textField', 'Registration Number', 20, 'new_party', max_len=100,
           help_text='Commercial registration or company number.')
t += pitem(p, 'ENTITY_TYPE', 'selectList', 'Entity Type', 30, 'new_party', lov=lookup_lov('ENTITY_TYPE'),
           help_text='Legal form of the organisation.')
t += pitem(p, 'INCORPORATION_DATE', 'datePicker', 'Date of Incorporation', 40, 'new_party')
t += pitem(p, 'DATE_OF_BIRTH', 'datePicker', 'Date of Birth', 50, 'new_party')
t += pitem(p, 'NATIONALITY', 'selectList', 'Nationality', 60, 'new_party', lov=lookup_lov('JURISDICTION'))
t += pitem(p, 'ID_TYPE', 'selectList', 'Identity Document', 70, 'new_party', lov=lookup_lov('ID_DOCUMENT_TYPE'))
t += pitem(p, 'ID_NUMBER', 'textField', 'Identity Document Number', 80, 'new_party', max_len=100)
t += pitem(p, 'JURISDICTION', 'selectList', 'Country', 90, 'new_party', lov=lookup_lov('JURISDICTION'),
           help_text='Country of incorporation for an organisation, country of residence for an individual.')
t += pitem(p, 'CONTACT_NAME', 'textField', 'Contact Person', 92, 'new_party', mark_required=True, max_len=240,
           help_text='Who the organisation deals with at the counterparty (or the individual).')
t += pitem(p, 'CONTACT_EMAIL', 'textField', 'Contact Email', 94, 'new_party', mark_required=True, max_len=320)
t += pitem(p, 'CONTACT_PHONE', 'textField', 'Contact Phone', 96, 'new_party', mark_required=True, max_len=50)
t += pitem(p, 'MATCH_ACK', 'switch', 'None of the listed parties is this counterparty', 100, 'new_party', default='N',
           help_text='Tick when you are sure none of the similar parties is the counterparty. Compliance still checks it.')
t += pitem(p, 'REQUESTING_DEPARTMENT', 'selectList', 'Requesting Department', 40, 'counterparty', required=True,
           lov=lookup_lov('REQUESTING_DEPARTMENT'),
           ro="xxcmp_request_pkg.can_choose_department = 'N' and xxcmp_request_pkg.default_department is not null",
           help_text='The department of your employee profile. Compliance can raise requests for any department.')
i = t.index('    pageItem P201_REQUESTING_DEPARTMENT (')
j = t.index('        readOnly {', i)
t = t[:j] + '''        default {
            type: sqlQuerySingleValue
            sqlQuerySingleValue:
                ```sql
                select xxcmp_request_pkg.default_department from dual
                ```
        }
''' + t[j:]
t += pitem(p, 'JUSTIFICATION', 'textarea', 'Business Purpose', 50, 'counterparty', max_len=4000, height=3,
           help_text='Why the organisation wants to deal with this counterparty.')
DATE_EXPR = "case :P201_PARTY_TYPE when 'ORGANIZATION' then to_date(:P201_INCORPORATION_DATE) else to_date(:P201_DATE_OF_BIRTH) end"
MATCH_ITEMS = 'P201_PARTY_TYPE,P201_PARTY_NAME,P201_REGISTRATION_NUMBER,P201_ID_NUMBER,P201_INCORPORATION_DATE,P201_DATE_OF_BIRTH,P201_JURISDICTION'
CAND_COLS = '''party_id number path '$.party_id', party_number varchar2(30) path '$.party_number',
                  registration_number varchar2(100) path '$.registration_number',
                  party_name varchar2(360) path '$.party_name', country varchar2(240) path '$.country',
                  score number path '$.score', reg_match number path '$.reg_match',
                  reasons varchar2(1000) path '$.reasons' '''.rstrip()
CAND_REPORT = [('PARTY_NAME', 'Name'), ('COUNTRY', 'Country'), ('SCORE', 'Match %'),
               ('REG_MATCH', 'Registration Match %'), ('REASONS', 'Why')]
t += classic('possible_matches', 'Existing Parties That May Be This Counterparty', f'''select j.party_id, j.party_number, j.registration_number,
       j.party_name, j.country, j.score, j.reg_match, j.reasons,
       'Use this party' as use_party
  from json_table(xxcmp_request_pkg.party_candidates_json(:P201_PARTY_TYPE, :P201_PARTY_NAME, :P201_REGISTRATION_NUMBER,
                      :P201_ID_NUMBER, {DATE_EXPR}, :P201_JURISDICTION), '$[*]'
         columns ({CAND_COLS})) j''',
             [('PARTY_ID', '', 'hidden'), ('PARTY_NUMBER', 'Party'), ('REGISTRATION_NUMBER', 'Registration No')] + CAND_REPORT + [
              ('USE_PARTY', 'Action', 'plainText',
               '<a href="#" class="kyc-use-party" data-party="#PARTY_ID#" data-label="#PARTY_NAME# (#PARTY_NUMBER#)">#USE_PARTY#</a>')],
             35, submit=MATCH_ITEMS, nodata='No existing party resembles this counterparty.')


def toggle(name, item, value, true_items, false_items, seq, extra=''):
    acts = ''
    for n, (act, items, when) in enumerate([('show', true_items, 'true'), ('hide', false_items, 'true'),
                                           ('hide', true_items, 'false'), ('show', false_items, 'false')]):
        if not items:
            continue
        sel = ('selectionType: region\n                region: @' + items[1:]) if items.startswith('@') else \
              ('selectionType: items\n                items: ' + items)
        acts += f'''
        action {name}-{n} (
            action: {act}
            affectedElements {{
                {sel}
            }}
            execution {{
                sequence: {(n + 1) * 10}
                fireWhenEventResultIs: {when}
                fireOnInit: true
            }}
        )
'''
    return f'''    dynamicAction {name} (
        name: {name}
        execution {{
            sequence: {seq}
        }}
        when {{
            event: change
            selectionType: items
            items: {item}
        }}
        clientSideCondition {{
            type: item=value
            item: {item}
            value: {value}
        }}
{acts}{extra}
    )

'''
# existing or new; then organisation or individual fields
t += toggle('existing-or-new', 'P201_PARTY_SELECTION', 'EXISTING', 'P201_PARTY_ID', '@new_party', 10)
t += toggle('existing-or-new-matches', 'P201_PARTY_SELECTION', 'EXISTING', '', '@possible_matches', 11)
t += toggle('fields-by-type', 'P201_PARTY_TYPE', 'ORGANIZATION', ORG_ITEMS, PERSON_ITEMS, 20)
t += f'''    dynamicAction refresh-matches (
        name: Look for similar parties
        execution {{
            sequence: 30
        }}
        when {{
            event: change
            selectionType: items
            items: {MATCH_ITEMS}
        }}

        action refresh-matches-refresh (
            action: refresh
            affectedElements {{
                selectionType: region
                region: @possible_matches
            }}
            execution {{
                sequence: 10
                fireOnInit: false
            }}
        )

    )

    dynamicAction match-ack-visibility (
        name: Confirmation only when there are similar parties
        execution {{
            sequence: 40
        }}
        when {{
            event: apexafterrefresh
            selectionType: region
            region: @possible_matches
        }}

        action match-ack-visibility-js (
            action: executeJsCode
            settings {{
                jsCode:
                    ```javascript
                    var found = $("#possible_matches a.kyc-use-party").length > 0;
                    apex.item("P201_MATCH_ACK").show();
                    if (!found) {{ apex.item("P201_MATCH_ACK").hide(); }}
                    ```
            }}
            execution {{
                sequence: 10
                fireOnInit: true
            }}
        )

    )

    dynamicAction use-party (
        name: Use an existing party
        execution {{
            sequence: 50
            eventScope: dynamic
            staticContainer: body
        }}
        when {{
            event: click
            selectionType: jQuerySelector
            jquerySelector: a.kyc-use-party
        }}

        action use-party-js (
            action: executeJsCode
            settings {{
                jsCode:
                    ```javascript
                    var a = $(this.triggeringElement);
                    this.browserEvent.preventDefault();
                    apex.item("P201_PARTY_SELECTION").setValue("EXISTING");
                    apex.item("P201_PARTY_ID").setValue(String(a.data("party")), a.data("label"));
                    ```
            }}
            execution {{
                sequence: 10
                fireOnInit: false
            }}
        )

    )

'''
t += button('cancel', 'CANCEL', 'Cancel', 10, 'buttons', 'CLOSE', action='redirectThisApp',
            target='page: 200', validations=False)
t += button('save-draft', 'SAVE_DRAFT', 'Save as Draft', 20, 'buttons', 'NEXT', auth='page-create', validations=False)
t += button('next', 'NEXT', 'Next', 30, 'buttons', 'NEXT', hot=True, auth='page-create')
t += process('load-request', 'Load draft', '''select party_selection, party_id, party_type, party_name, registration_number, entity_type,
       incorporation_date, date_of_birth, nationality, id_type, id_number, jurisdiction, match_ack_flag,
       requesting_department, justification, contact_name, contact_email, contact_phone
  into :P201_PARTY_SELECTION, :P201_PARTY_ID, :P201_PARTY_TYPE, :P201_PARTY_NAME, :P201_REGISTRATION_NUMBER, :P201_ENTITY_TYPE,
       :P201_INCORPORATION_DATE, :P201_DATE_OF_BIRTH, :P201_NATIONALITY, :P201_ID_TYPE, :P201_ID_NUMBER, :P201_JURISDICTION,
       :P201_MATCH_ACK, :P201_REQUESTING_DEPARTMENT, :P201_JUSTIFICATION, :P201_CONTACT_NAME, :P201_CONTACT_EMAIL,
       :P201_CONTACT_PHONE
  from xxcmp_requests
 where request_id = :P201_REQUEST_ID and request_status = 'DRAFT';''', 10, point='beforeHeader',
                 condition='type: itemIsNotNull\nitem: P201_REQUEST_ID')
NEW = ":P201_PARTY_SELECTION = 'NEW' and "
checks = [
    ('PARTY_ID', ":P201_PARTY_SELECTION = 'EXISTING' and :P201_PARTY_ID is null", 'Choose the existing counterparty.'),
    ('PARTY_NAME', NEW + "trim(:P201_PARTY_NAME) is null", 'Enter the name.'),
    ('INCORPORATION_DATE', NEW + ":P201_PARTY_TYPE = 'ORGANIZATION' and to_date(:P201_INCORPORATION_DATE) > trunc(sysdate)",
     'The date of incorporation cannot be in the future.'),
    ('DATE_OF_BIRTH', NEW + ":P201_PARTY_TYPE = 'PERSON' and to_date(:P201_DATE_OF_BIRTH) > trunc(sysdate)",
     'The date of birth cannot be in the future.'),
    ('CONTACT_NAME', NEW + "trim(:P201_CONTACT_NAME) is null", 'Enter the contact person.'),
    ('CONTACT_EMAIL', NEW + "trim(:P201_CONTACT_EMAIL) is null", 'Enter the contact email.'),
    ('CONTACT_EMAIL', NEW + "not regexp_like(trim(:P201_CONTACT_EMAIL), '^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$')",
     'Enter a valid contact email.'),
    ('CONTACT_PHONE', NEW + "trim(:P201_CONTACT_PHONE) is null", 'Enter the contact phone.'),
    ('MATCH_ACK', NEW + "nvl(:P201_MATCH_ACK, 'N') <> 'Y'\n   and xxcmp_request_pkg.party_candidate_count(:P201_PARTY_TYPE, :P201_PARTY_NAME, :P201_REGISTRATION_NUMBER,\n"
                        f"         :P201_ID_NUMBER, {DATE_EXPR}, :P201_JURISDICTION) > 0",
     'Existing parties may be this counterparty: choose one with Use this party, or confirm that none of them is.'),
]
for i, (fld, check, msg) in enumerate(checks):
    t += fn_validation(f'check-{i + 1}', msg, f"if {check} then\n    return '{msg}';\nend if;\nreturn null;",
                       f'P201_{fld}', (i + 1) * 10, requests='NEXT')
# same registration / identity number and country as an existing party: never a new party, even when confirmed
t += fn_validation('check-exact', 'Party already exists', '''declare
    l_party varchar2(30);
begin
    if :P201_PARTY_SELECTION = 'NEW' then
        l_party := xxcmp_request_pkg.exact_party_number(:P201_PARTY_TYPE, :P201_REGISTRATION_NUMBER, :P201_ID_NUMBER,
                                                        :P201_JURISDICTION);
        if l_party is not null then
            return 'Party ' || l_party || ' already has this registration number and country: use this party.';
        end if;
    end if;
    return null;
end;''', 'P201_REGISTRATION_NUMBER', 5, requests='NEXT')
t += process('save-request', 'Save counterparty', '''declare
    l_request_id number := to_number(:P201_REQUEST_ID);
begin
    -- one rule set for the page and the database; Save as Draft only needs the type and a name or party
    xxcmp_request_pkg.save_counterparty(
        p_request_id            => l_request_id,
        p_party_selection       => :P201_PARTY_SELECTION,
        p_party_id              => to_number(:P201_PARTY_ID),
        p_party_type            => :P201_PARTY_TYPE,
        p_party_name            => :P201_PARTY_NAME,
        p_registration_number   => :P201_REGISTRATION_NUMBER,
        p_entity_type           => :P201_ENTITY_TYPE,
        p_incorporation_date    => to_date(:P201_INCORPORATION_DATE),
        p_id_type               => :P201_ID_TYPE,
        p_id_number             => :P201_ID_NUMBER,
        p_jurisdiction          => :P201_JURISDICTION,
        p_date_of_birth         => to_date(:P201_DATE_OF_BIRTH),
        p_nationality           => :P201_NATIONALITY,
        p_requesting_department => :P201_REQUESTING_DEPARTMENT,
        p_justification         => :P201_JUSTIFICATION,
        p_match_ack             => nvl(:P201_MATCH_ACK, 'N'),
        p_draft                 => case when :REQUEST = 'SAVE_DRAFT' then 'Y' else 'N' end,
        p_contact_name          => :P201_CONTACT_NAME,
        p_contact_email         => :P201_CONTACT_EMAIL,
        p_contact_phone         => :P201_CONTACT_PHONE);
    :P201_REQUEST_ID := l_request_id;
end;''', 10, requests='NEXT,SAVE_DRAFT', auth='page-create', success='Request saved.')
t += branch('Draft saved', 200, {}, seq=10, button_='save-draft')
t += branch('To questionnaire', 202, {'P202_REQUEST_ID': '&P201_REQUEST_ID.'}, seq=20, button_='next')
t += ')\n'
write('p00201-create-request.apx', t)

# ===================================================================== 202
p = 202
t = page_header(p, 'Create Request - Questionnaire', 'CREATE-REQUEST-QUESTIONNAIRE', 'kyc',
                'Step 2 of 3: answer every question. The answers decide whether a KYC review is needed.')
# page-level look of the questionnaire form and the binding of its answers (kyc-app.js)
t = t.replace('''    security {
        authorizationScheme: @page-view''', '''    javaScript {
        executeWhenPageLoads:
            ```javascript-browser
            kycQuestionnaire.bind('answers', 'P202_ANSWERS');
            ```
    }
    css {
        inline:
            ```css
            .kyc-section { margin-bottom: 1.5rem; }
            .kyc-section-title { font-size: 1rem; font-weight: 600; margin: 0 0 .75rem;
                                 padding-bottom: .25rem; border-bottom: 1px solid var(--ut-component-border-color, #ddd); }
            .kyc-q { border: 0; margin: 0 0 1rem; padding: 0; }
            .kyc-q-text { font-weight: 500; margin-bottom: .4rem; padding: 0; }
            .kyc-q-required { color: var(--ut-palette-danger, #c00); }
            .kyc-q-options { display: flex; flex-wrap: wrap; gap: .5rem 1.5rem; }
            .kyc-q-option { display: inline-flex; align-items: center; gap: .35rem; cursor: pointer; }
            .kyc-q-input { width: 100%; max-width: 40rem; }
            ```
    }
    security {
        authorizationScheme: @page-view''', 1)
t += breadcrumb_region('Create Request') + '\n'
t += wizard_region()
t += static_region('buttons', 'Buttons', 90, template='buttons-container')
t += pitem(p, 'REQUEST_ID', 'hidden', None, 1, 'buttons', protect=True)
t += '''    pageItem P202_ANSWERS (
        type: hidden
        layout {
            sequence: 2
            region: @buttons
            slot: regionBody
        }
        sessionState {
            dataType: clob
        }
        settings {
            valueProtected: false
        }
        security {
            sessionStateProtection: unrestricted
        }
        comments {
            comments:
                ```
                Unrestricted on purpose: filled in the browser just before submit by kycQuestionnaire (kyc-app.js). XXCMP_REQUEST_PKG.ANSWERS_ERROR / SAVE_ANSWERS re-check every question and option on the server.
                ```
        }
    )

    region answers (
        name: Questionnaire
        type: dynamicContent
        source {
            language: plsql
            plsqlFunctionBody:
                ```plsql
                return xxcmp_request_pkg.questionnaire_html(:P202_REQUEST_ID);
                ```
            pageItemsToSubmit: P202_REQUEST_ID
        }
        layout {
            sequence: 20
            slot: BODY
        }
        appearance {
            template: @/standard
            templateOptions: #DEFAULT#
        }
        advanced {
            htmlDomId: answers
        }
    )

'''
t += button('previous', 'PREVIOUS', 'Previous', 10, 'buttons', 'PREVIOUS', validations=False)
t += button('save-draft', 'SAVE_DRAFT', 'Save as Draft', 15, 'buttons', 'NEXT', auth='page-create', validations=False)
t += button('next', 'NEXT', 'Next', 20, 'buttons', 'NEXT', hot=True, auth='page-create')
t += fn_validation('required-answers', 'Required questions answered',
                   'return xxcmp_request_pkg.answers_error(:P202_REQUEST_ID, :P202_ANSWERS);',
                   'P202_ANSWERS', 10, requests='NEXT')
t += process('save-answers', 'Save answers',
             'xxcmp_request_pkg.save_answers(:P202_REQUEST_ID, :P202_ANSWERS);', 10,
             requests='NEXT,PREVIOUS,SAVE_DRAFT', auth='page-create')
t += branch('Draft saved', 200, {}, seq=5, button_='save-draft')
t += branch('Back to counterparty', 201, {'P201_REQUEST_ID': '&P202_REQUEST_ID.'}, seq=10, button_='previous')
t += branch('To review', 203, {'P203_REQUEST_ID': '&P202_REQUEST_ID.'}, seq=20, button_='next')
t += ')\n'
write('p00202-create-request-questionnaire.apx', t)

# ===================================================================== 203
p = 203
t = page_header(p, 'Create Request - Review and Submit', 'CREATE-REQUEST-SUBMIT', 'kyc',
                'Step 3 of 3: attach the documents you have and submit. You will see the outcome on the request.')
t += breadcrumb_region('Create Request') + '\n'
t += wizard_region()
t += static_region('summary', 'Summary', 20)
t += static_region('buttons', 'Buttons', 90, template='buttons-container')
t += pitem(p, 'REQUEST_ID', 'hidden', None, 1, 'summary', protect=True)
t += pitem(p, 'REQUEST_NUMBER', 'displayOnly', 'Request', 10, 'summary',
           sql='select request_number from xxcmp_requests where request_id = :P203_REQUEST_ID')
t += pitem(p, 'COUNTERPARTY', 'displayOnly', 'Counterparty', 20, 'summary',
           sql="""select party_name || ' (' || xxfnd_util_pkg.lookup_meaning('PARTY_TYPE', party_type)
       || nvl2(jurisdiction, ', ' || xxfnd_util_pkg.lookup_meaning('JURISDICTION', jurisdiction), null) || ')'
  from xxcmp_requests where request_id = :P203_REQUEST_ID""")
t += pitem(p, 'SUBMIT_CHECK', 'displayOnly', 'Ready to Submit', 30, 'summary',
           sql="select nvl(xxcmp_request_pkg.submit_error(:P203_REQUEST_ID), 'Yes') from dual")
t += classic('answer_summary', 'Answers', '''select (select q.question_text from xxcmp_questions q where q.question_id = a.question_id) as question,
       coalesce((select o.answer_label from xxcmp_answer_options o where o.answer_option_id = a.answer_option_id), a.answer_text, '-') as answer
  from xxcmp_request_answers a
 where a.request_id = :P203_REQUEST_ID and a.respondent_type = 'REQUESTER'
 order by (select q.display_sequence from xxcmp_questions q where q.question_id = a.question_id)''',
             [('QUESTION', 'Question'), ('ANSWER', 'Answer')], 30, submit='P203_REQUEST_ID')
t += classic('request_attachments', 'Documents', '''select a.attached_document_id, a.title, a.category_name, a.document_date, a.expiry_date, a.created_by, a.creation_date
  from xxfnd_attached_documents_v a
 where a.entity_name = 'XXCMP_REQUESTS' and a.pk1_value = :P203_REQUEST_ID
 order by a.seq_num, a.creation_date''',
             [('ATTACHED_DOCUMENT_ID', '', 'hidden'), ('TITLE', 'Title'), ('CATEGORY_NAME', 'Category'),
              ('DOCUMENT_DATE', 'Document Date'), ('EXPIRY_DATE', 'Expires'), ('CREATED_BY', 'Added By'),
              ('CREATION_DATE', 'Added On')], 40, submit='P203_REQUEST_ID', nodata='No documents attached yet.')
t += button('request_attachments-add', 'REQUEST_ATTACHMENTS_ADD', 'Add Document', 10, 'request_attachments', 'EDIT',
            action='redirectThisApp',
            target='page: 90\nitems: {\n    P90_ENTITY_NAME: XXCMP_REQUESTS\n    P90_PK1_VALUE: &P203_REQUEST_ID.\n    P90_SOURCE_PAGE: 203\n    P90_SOURCE_REGION: request_attachments\n}\nclearCache: 90',
            condition="type: expression\nlanguage: plsql\nplsqlExpression:\n    ```plsql\n    xxfnd_attach_pkg.block_permission(:APP_ALIAS, 203, 'request_attachments', 'XXCMP_REQUESTS', 'INSERT') = 'Y'\n    ```",
            validations=False)
t += refresh_da('request_attachments', 30)
t += button('previous', 'PREVIOUS', 'Previous', 10, 'buttons', 'PREVIOUS', action='redirectThisApp',
            target='page: 202\nitems: {\n    P202_REQUEST_ID: &P203_REQUEST_ID.\n}\nclearCache: 202', validations=False)
t += button('save-draft', 'SAVE_DRAFT', 'Save as Draft', 15, 'buttons', 'NEXT', action='redirectThisApp',
            target='page: 200', validations=False)
t += button('submit', 'SUBMIT', 'Submit Request', 20, 'buttons', 'NEXT', hot=True, auth='page-create')
t += fn_validation('submit-check', 'Request complete', 'return xxcmp_request_pkg.submit_error(:P203_REQUEST_ID);',
                   'P203_SUBMIT_CHECK', requests='SUBMIT')
t += process('submit-request', 'Submit request', 'xxcmp_request_pkg.submit(:P203_REQUEST_ID);', 10,
             button_='submit', auth='page-create', success='Request submitted.')
t += branch('To the request', 205, {'P205_REQUEST_ID': '&P203_REQUEST_ID.'}, button_='submit')
t += ')\n'
write('p00203-create-request-submit.apx', t)

# ===================================================================== 205
p = 205
t = page_header(p, 'KYC Request', 'KYC-REQUEST', 'kyc',
                'A KYC request: where it stands, the answers and the documents. Compliance reviews the document checklist here.')
t += breadcrumb_region('KYC Request') + '\n'
t += static_region('request', 'Request', 20)
t += static_region('buttons', 'Buttons', 15, slot='REGION_POSITION_01', template='buttons-container')
t += pitem(p, 'REQUEST_ID', 'hidden', None, 1, 'request', protect=True)
t += pitem(p, 'TASK_ID', 'hidden', None, 2, 'request', protect=True)
t += pitem(p, 'CASE_ID', 'hidden', None, 3, 'request', protect=True)
for i, (name, label, sql) in enumerate([
        ('REQUEST_NUMBER', 'Request', "select request_number from xxcmp_requests where request_id = :P205_REQUEST_ID"),
        ('STAGE', 'Stage', "select xxcmp_request_pkg.stage(:P205_REQUEST_ID) from dual"),
        ('COUNTERPARTY', 'Counterparty', """select party_name || ' (' || xxfnd_util_pkg.lookup_meaning('PARTY_TYPE', party_type)
       || nvl2(registration_number, ', ' || registration_number, null)
       || nvl2(jurisdiction, ', ' || xxfnd_util_pkg.lookup_meaning('JURISDICTION', jurisdiction), null) || ')'
  from xxcmp_requests where request_id = :P205_REQUEST_ID"""),
        ('REQUEST_TYPE', 'Type', "select xxfnd_util_pkg.lookup_meaning('KYC_REQUEST_TYPE', request_type) from xxcmp_requests where request_id = :P205_REQUEST_ID"),
        ('INTAKE', 'Intake Result', """select xxfnd_util_pkg.lookup_meaning('KYC_INTAKE_OUTCOME', intake_outcome)
       || nvl2(intake_score, ' (score ' || intake_score || case when intake_critical_flag = 'Y' then ', critical answer' end || ')', null)
  from xxcmp_requests where request_id = :P205_REQUEST_ID"""),
        ('REQUESTED_BY', 'Requested By', """select requester_user_name || nvl2(requesting_department, ' - '
       || xxfnd_util_pkg.lookup_meaning('REQUESTING_DEPARTMENT', requesting_department), null)
  from xxcmp_requests where request_id = :P205_REQUEST_ID"""),
        ('JUSTIFICATION', 'Business Purpose', "select justification from xxcmp_requests where request_id = :P205_REQUEST_ID"),
        ('PARTY', 'Party', """select case when p.party_id is not null then p.party_number || ' - ' || p.party_name
            when r.party_id is not null then 'Linked to a party'
            else 'Not decided yet' end
       || nvl2(r.match_status, ' (' || xxfnd_util_pkg.lookup_meaning('REQUEST_MATCH_STATUS', r.match_status) || ')', null)
  from xxcmp_requests r
  left join xxcmp_parties p on p.party_id = r.party_id
 where r.request_id = :P205_REQUEST_ID"""),
        ('CASE_NUMBER', 'Case', "select max(case_number) from xxcmp_cases where request_id = :P205_REQUEST_ID")]):
    t += pitem(p, name, 'displayOnly', label, (i + 1) * 10, 'request', sql=sql)
t += classic('answer_summary', 'Answers', '''select (select q.question_text from xxcmp_questions q where q.question_id = a.question_id) as question,
       coalesce((select o.answer_label from xxcmp_answer_options o where o.answer_option_id = a.answer_option_id), a.answer_text, '-') as answer,
       a.risk_points
  from xxcmp_request_answers a
 where a.request_id = :P205_REQUEST_ID and a.respondent_type = 'REQUESTER'
 order by (select q.display_sequence from xxcmp_questions q where q.question_id = a.question_id)''',
             [('QUESTION', 'Question'), ('ANSWER', 'Answer'), ('RISK_POINTS', 'Points')], 30, submit='P205_REQUEST_ID')
t += classic('checklist', 'Document Checklist', '''select c.column_value as category_code,
       (select nvl(tl.category_name, dc.category_name) from xxfnd_document_categories dc
          left join xxfnd_document_categories_tl tl on tl.category_code = dc.category_code and tl.language_code = xxfnd_util_pkg.current_lang
         where dc.category_code = c.column_value) as category,
       case when exists (select 1 from xxfnd_attached_documents_v a
                          where a.category_code = c.column_value and nvl(a.expired_flag, 'N') = 'N'
                            and ((a.entity_name = 'XXCMP_REQUESTS' and a.pk1_value = :P205_REQUEST_ID)
                              or (a.entity_name = 'XXCMP_PARTIES' and a.pk1_value = (select to_char(party_id) from xxcmp_requests where request_id = :P205_REQUEST_ID))))
            then 'Present' else 'Missing' end as status
  from table(xxcmp_kyc_pkg.mandatory_categories('XXCMP_PARTIES',
                 (select jurisdiction from xxcmp_requests where request_id = :P205_REQUEST_ID),
                 (select entity_type from xxcmp_requests where request_id = :P205_REQUEST_ID))) c''',
             [('CATEGORY_CODE', '', 'hidden'), ('CATEGORY', 'Mandatory Document'), ('STATUS', 'Status')], 40,
             submit='P205_REQUEST_ID', nodata='No mandatory documents are configured for this counterparty.',
             condition="type: expression\nlanguage: plsql\nplsqlExpression:\n    ```plsql\n    xxfnd_privilege_pkg.has_privilege('CASES', 'VIEW')\n    ```")
# the match decision is part of the checklist review task (workflow 1.2): shown to Compliance on the task;
# requests started on workflow 1.1 still come with a Counterparty Match task
MATCH_MANAGER = ("type: functionBody\nlanguage: plsql\nplsqlFunctionBody:\n    ```plsql\n"
                 "    if xxcmp_request_pkg.match_pending(:P205_REQUEST_ID) <> 'Y'\n"
                 "       or not xxfnd_privilege_pkg.has_privilege('PARTIES', 'MANAGE') then\n"
                 "        return false;\n    end if;\n"
                 "    for t in (select 1 from apex_tasks where task_id = :P205_TASK_ID\n"
                 "                 and task_def_static_id in ('DOC_CHECKLIST_REVIEW', 'COUNTERPARTY_MATCH')) loop\n"
                 "        return apex_human_task.is_allowed(p_task_id => :P205_TASK_ID, p_operation => apex_human_task.c_task_op_approve)\n"
                 "            or apex_human_task.is_allowed(p_task_id => :P205_TASK_ID, p_operation => apex_human_task.c_task_op_claim);\n"
                 "    end loop;\n    return false;\n    ```")
t += static_region('counterparty_matching', 'Counterparty Matching', 50,
                   html='<p>Part of this review: the counterparty was entered as new, but existing parties may be the same. '
                        'Merge it into one of them (the request is linked to that party and its empty fields are completed '
                        'from the request), or confirm it as a new party. The checklist can be approved once this is decided.</p>',
                   condition=MATCH_MANAGER)
t += pitem(p, 'MERGE_PARTY_ID', 'hidden', None, 1, 'counterparty_matching')
t = t.replace('''    pageItem P205_MERGE_PARTY_ID (
        type: hidden''', '''    pageItem P205_MERGE_PARTY_ID (
        type: hidden
        settings {
            valueProtected: false
        }
        security {
            sessionStateProtection: unrestricted
        }
        comments {
            comments: Set by the Merge link just before submit. XXCMP_REQUEST_PKG.RESOLVE_MATCH re-checks the privilege, the pending state and the party type.
        }''', 1)
t += pitem(p, 'MATCH_NOTE', 'textarea', 'Decision Note', 10, 'counterparty_matching', max_len=1000, height=2,
           help_text='Why the counterparty is (or is not) one of the existing parties.')
t += classic('match_candidates', 'Existing Parties That May Be This Counterparty', f'''select j.party_id, j.party_number, j.registration_number,
       j.party_name, j.country, j.score, j.reg_match, j.reasons,
       apex_page.get_url(p_page => 21, p_items => 'P21_PARTY_ID', p_values => to_char(j.party_id), p_clear_cache => '21') as party_url,
       'Merge into this party' as merge
  from json_table(xxcmp_request_pkg.request_candidates_json(:P205_REQUEST_ID), '$[*]'
         columns ({CAND_COLS})) j''',
             [('PARTY_ID', '', 'hidden'), ('PARTY_URL', '', 'hidden'),
              ('PARTY_NUMBER', 'Party', 'plainText', '<a href="#PARTY_URL#" target="_blank">#PARTY_NUMBER#</a>'),
              ('REGISTRATION_NUMBER', 'Registration No')] + CAND_REPORT + [
              ('MERGE', 'Action', 'plainText',
               '<a href="#" class="kyc-merge-party" data-party="#PARTY_ID#" data-label="#PARTY_NAME# (#PARTY_NUMBER#)">#MERGE#</a>')],
             20, submit='P205_REQUEST_ID', nodata='No existing party resembles this counterparty any more.',
             parent='counterparty_matching')
t += button('confirm-new', 'CONFIRM_NEW', 'Confirm as New Party', 10, 'counterparty_matching', 'EDIT',
            condition=MATCH_MANAGER, auth='page-view', confirm='Create a new party for this counterparty?')
t += '''    dynamicAction merge-party (
        name: Merge into an existing party
        execution {
            sequence: 60
            eventScope: dynamic
            staticContainer: body
        }
        when {
            event: click
            selectionType: jQuerySelector
            jquerySelector: a.kyc-merge-party
        }

        action merge-party-js (
            action: executeJsCode
            settings {
                jsCode:
                    ```javascript
                    var a = $(this.triggeringElement);
                    this.browserEvent.preventDefault();
                    apex.message.confirm("Merge this counterparty into " + a.data("label") + "?", function (ok) {
                        if (ok) {
                            apex.page.submit({ request: "MERGE", set: { P205_MERGE_PARTY_ID: String(a.data("party")) } });
                        }
                    });
                    ```
            }
            execution {
                sequence: 10
                fireOnInit: false
            }
        )

    )

'''
t += process('merge-party', 'Merge into existing party',
             'xxcmp_request_pkg.resolve_match(:P205_REQUEST_ID, to_number(:P205_MERGE_PARTY_ID), :P205_MATCH_NOTE);', 5,
             requests='MERGE', success='The counterparty was merged into the existing party.')
t += process('confirm-new-party', 'Confirm as new party',
             'xxcmp_request_pkg.resolve_match(:P205_REQUEST_ID, null, :P205_MATCH_NOTE);', 6,
             button_='confirm-new', success='A new party was created for the counterparty.')
t += classic('request_attachments', 'Documents', '''select a.attached_document_id, a.title, a.category_name, a.document_date, a.expiry_date,
       case when a.expired_flag = 'Y' then 'Expired' end as expired, a.created_by, a.creation_date
  from xxfnd_attached_documents_v a
 where a.entity_name = 'XXCMP_REQUESTS' and a.pk1_value = :P205_REQUEST_ID
 order by a.seq_num, a.creation_date''',
             [('ATTACHED_DOCUMENT_ID', '', 'hidden'), ('TITLE', 'Title'), ('CATEGORY_NAME', 'Category'),
              ('DOCUMENT_DATE', 'Document Date'), ('EXPIRY_DATE', 'Expires'), ('EXPIRED', 'Expired'),
              ('CREATED_BY', 'Added By'), ('CREATION_DATE', 'Added On')], 60, submit='P205_REQUEST_ID',
             nodata='No documents attached.')
t += button('request_attachments-add', 'REQUEST_ATTACHMENTS_ADD', 'Add Document', 10, 'request_attachments', 'EDIT',
            action='redirectThisApp',
            target='page: 90\nitems: {\n    P90_ENTITY_NAME: XXCMP_REQUESTS\n    P90_PK1_VALUE: &P205_REQUEST_ID.\n    P90_SOURCE_PAGE: 205\n    P90_SOURCE_REGION: request_attachments\n}\nclearCache: 90',
            condition="type: expression\nlanguage: plsql\nplsqlExpression:\n    ```plsql\n    xxfnd_attach_pkg.block_permission(:APP_ALIAS, 205, 'request_attachments', 'XXCMP_REQUESTS', 'INSERT') = 'Y'\n    ```",
            validations=False)
t += refresh_da('request_attachments', 30)
TASK_ALLOWED = ("type: functionBody\nlanguage: plsql\nplsqlFunctionBody:\n    ```plsql\n"
                "    -- the document checklist task of this request (the page also opens from the Counterparty Match task)\n"
                "    for t in (select 1 from apex_tasks where task_id = :P205_TASK_ID and task_def_static_id = 'DOC_CHECKLIST_REVIEW') loop\n"
                "        return apex_human_task.is_allowed(p_task_id => :P205_TASK_ID, p_operation => apex_human_task.c_task_op_approve)\n"
                "            or apex_human_task.is_allowed(p_task_id => :P205_TASK_ID, p_operation => apex_human_task.c_task_op_claim);\n"
                "    end loop;\n    return false;\n    ```")
t += static_region('decision', 'Checklist Decision', 70, html='<p>Approve opens the case for investigation. Reject closes the request. For a missing document, raise a request for information instead.</p>',
                   condition=TASK_ALLOWED)
t += pitem(p, 'COMMENT', 'textarea', 'Comment', 10, 'decision', max_len=1000, height=2,
           help_text='Recorded on the task; required when rejecting.')
t += button('approve', 'APPROVE', 'Approve - Open Case', 30, 'decision', 'NEXT', hot=True,
            condition=TASK_ALLOWED.replace("    for t in", "    if xxcmp_request_pkg.match_pending(:P205_REQUEST_ID) = 'Y' then\n        return false;\n    end if;\n    for t in", 1))
t += button('reject', 'REJECT', 'Reject Request', 20, 'decision', 'DELETE', condition=TASK_ALLOWED,
            confirm='Reject this request?')
t += button('raise-rfi', 'RAISE_RFI', 'Raise RFI', 10, 'decision', 'EDIT', action='redirectThisApp',
            target='page: 32\nitems: {\n    P32_ENTITY_NAME: XXCMP_REQUESTS\n    P32_PK1_VALUE: &P205_REQUEST_ID.\n}\nclearCache: 32',
            condition=TASK_ALLOWED, validations=False)
t += button('edit-draft', 'EDIT_DRAFT', 'Continue Draft', 10, 'buttons', 'EDIT', action='redirectThisApp',
            target='page: 201\nitems: {\n    P201_REQUEST_ID: &P205_REQUEST_ID.\n}\nclearCache: 201',
            condition="type: rowsReturned\nsqlQuery:\n    ```sql\n    select 1 from xxcmp_requests where request_id = :P205_REQUEST_ID and request_status = 'DRAFT'\n    ```",
            auth='page-manage', validations=False)
t += button('open-case', 'OPEN_CASE', 'Open Case', 20, 'buttons', 'NEXT', action='redirectThisApp',
            target='page: 211\nitems: {\n    P211_CASE_ID: &P205_CASE_ID.\n}\nclearCache: 211',
            condition="type: expression\nlanguage: plsql\nplsqlExpression:\n    ```plsql\n    :P205_CASE_ID is not null and xxfnd_privilege_pkg.has_privilege('CASES', 'VIEW')\n    ```",
            validations=False)
t += fn_validation('reject-reason', 'Reason for rejection',
                   "return case when :P205_COMMENT is null then 'Enter why the request is rejected.' end;",
                   'P205_COMMENT', requests='REJECT')
t += process('open-from-task', 'Open from task', '''select to_number(detail_pk) into :P205_REQUEST_ID
  from table ( apex_human_task.get_tasks (
                   p_context        => 'SINGLE_TASK',
                   p_task_id        => :P205_TASK_ID,
                   p_application_id => :APP_ID ) )
 where task_def_static_id in ('DOC_CHECKLIST_REVIEW', 'COUNTERPARTY_MATCH');''', 5, point='beforeHeader',
             condition='type: itemIsNotNull\nitem: P205_TASK_ID')
t += process('load-case', 'Load case', '''select max(case_id) into :P205_CASE_ID from xxcmp_cases where request_id = :P205_REQUEST_ID;
-- the breadcrumb shows the request number before the page items are rendered
select max(request_number) into :P205_REQUEST_NUMBER from xxcmp_requests where request_id = :P205_REQUEST_ID;''',
             6, point='beforeHeader')
t += process('add-comment', 'Record comment', 'apex_human_task.add_task_comment(p_task_id => :P205_TASK_ID, p_text => :P205_COMMENT);',
             10, requests='APPROVE,REJECT', condition=None)
t += process('approve-task', 'Approve checklist', 'apex_human_task.approve_task(p_task_id => :P205_TASK_ID, p_autoclaim => true);',
             20, button_='approve', success='Checklist approved: the case will be opened.')
t += process('reject-task', 'Reject request', 'apex_human_task.reject_task(p_task_id => :P205_TASK_ID, p_autoclaim => true);',
             30, button_='reject', success='Request rejected.')
t += ')\n'
# only record a comment when one was entered
t = t.replace('''        serverSideCondition {
            type: requestIsContainedInValue
            value: APPROVE,REJECT
        }
    )''', '''        serverSideCondition {
            type: itemIsNotNull
            item: P205_COMMENT
        }
    )''')
write('p00205-kyc-request.apx', t)

# ===================================================================== 210
CASE_LIST_SQL = '''select q.*,
       apex_page.get_url(p_page => 211, p_items => 'P211_CASE_ID', p_values => to_char(q.case_id), p_clear_cache => '211') as open_url
  from (
        select c.case_id,
               c.case_number,
               p.party_name,
               xxfnd_util_pkg.lookup_meaning('CASE_STATUS', c.case_status) as case_status,
               c.assigned_to,
               xxfnd_util_pkg.lookup_meaning('RISK_TIER', c.risk_tier) as risk_tier,
               case when c.enhanced_kyc_flag = 'Y' then 'Enhanced' end as kyc_level,
               c.sla_due_date,
               case when c.closed_date is not null then 'Closed'
                    when c.sla_due_date < trunc(sysdate) then 'Overdue'
                    when c.sla_due_date <= trunc(sysdate) + 2 then 'Due soon'
                    else 'On time' end as sla_status,
               r.request_number,
               xxfnd_util_pkg.lookup_meaning('KYC_REQUEST_TYPE', r.request_type) as request_type,
               c.next_review_date,
               c.creation_date
          from xxcmp_cases c
          join xxcmp_parties p on p.party_id = c.party_id
          join xxcmp_requests r on r.request_id = c.request_id
       ) q'''
write('p00210-cases.apx', list_page(
    210, 'Cases', 'CASES', 'kyc',
    'The Compliance case workbench: open cases with their SLA status, and closed cases with their next review. '
    'Cases are opened when a request passes the document checklist, by a periodic review, or here with Create Case.',
    CASE_LIST_SQL,
    [col('CASE_ID', 'Case Id', 10, kind='hidden', dtype='NUMBER', pk=True),
     col('CASE_NUMBER', 'Case', 20, link='OPEN_URL'),
     col('PARTY_NAME', 'Party', 30),
     col('CASE_STATUS', 'Status', 40),
     col('SLA_STATUS', 'SLA', 50),
     col('SLA_DUE_DATE', 'SLA Due', 60, dtype='DATE'),
     col('ASSIGNED_TO', 'Assigned To', 70),
     col('RISK_TIER', 'Risk', 80),
     col('KYC_LEVEL', 'KYC Level', 90),
     col('REQUEST_NUMBER', 'Request', 100),
     col('REQUEST_TYPE', 'Type', 110),
     col('NEXT_REVIEW_DATE', 'Next Review', 120, dtype='DATE'),
     col('CREATION_DATE', 'Opened', 130, dtype='DATE', fmt='SINCE'),
     col('OPEN_URL', 'Open Url', 140, kind='hidden')],
    create_label='Create Case', form_page=216))

# ===================================================================== 211
p = 211
IS_OPEN = "type: rowsReturned\nsqlQuery:\n    ```sql\n    select 1 from xxcmp_cases where case_id = :P211_CASE_ID and case_status = 'INVESTIGATION'\n    ```"
t = page_header(p, 'Case', 'CASE', 'kyc',
                'Case 360: everything about one case. The officer records screenings, verifies documents, determines the '
                'beneficial owners, answers the investigation questionnaire, sets the risk and submits the case for approval.',
                read_only="xxcmp_case_pkg.is_editable(:P211_CASE_ID) = 'N'")
t += breadcrumb_region('Case') + '\n'
t += static_region('buttons', 'Buttons', 15, slot='REGION_POSITION_01', template='buttons-container')
t += '''    region case (
        name: Case
        type: form
        source {
            location: localDatabase
            type: tableView
            tableName: XXCMP_CASES
        }
        layout {
            sequence: 20
            slot: BODY
        }
        appearance {
            template: @/standard
            templateOptions: #DEFAULT#
        }
        edit {
            enabled: true
            allowedOperations: [
                update
            ]
        }
        advanced {
            htmlDomId: case
        }
    )

'''
t += item(p, 'CASE_ID', 'hidden', None, 1, 'CASE_ID', dtype='number', pk=True, region='case')
t += pitem(p, 'TASK_ID', 'hidden', None, 2, 'case', protect=True)
t += pitem(p, 'PARTY_ID', 'hidden', None, 3, 'case', protect=False)
t += pitem(p, 'WORKFLOW_ID', 'hidden', None, 4, 'case', protect=False)
t += item(p, 'CASE_NUMBER', 'displayOnly', 'Case', 10, 'CASE_NUMBER', region='case')
t += pitem(p, 'PARTY', 'displayOnly', 'Party', 20, 'case', sql="""select p.party_number || ' - ' || p.party_name
       || nvl2(p.jurisdiction, ' (' || xxfnd_util_pkg.lookup_meaning('JURISDICTION', p.jurisdiction) || ')', null)
  from xxcmp_cases c join xxcmp_parties p on p.party_id = c.party_id where c.case_id = :P211_CASE_ID""")
t += pitem(p, 'STATUS', 'displayOnly', 'Status', 30, 'case', sql="""select xxfnd_util_pkg.lookup_meaning('CASE_STATUS', case_status)
       || case when case_status = 'PENDING_APPROVAL' then ' (level ' || current_level || ')' end
       || nvl2(closed_date, ' - closed ' || to_char(closed_date, 'DD-Mon-YYYY'), null)
  from xxcmp_cases where case_id = :P211_CASE_ID""")
t += pitem(p, 'SLA', 'displayOnly', 'SLA Due', 40, 'case', sql="""select to_char(sla_due_date, 'DD-Mon-YYYY')
       || case when closed_date is null and sla_due_date < trunc(sysdate) then ' - OVERDUE' end
  from xxcmp_cases where case_id = :P211_CASE_ID""")
t += pitem(p, 'REQUEST', 'displayOnly', 'Request', 50, 'case', sql="""select r.request_number || ' - '
       || xxfnd_util_pkg.lookup_meaning('KYC_REQUEST_TYPE', r.request_type)
       || ' - intake score ' || nvl(to_char(r.intake_score), '-') || ' (reference only)'
  from xxcmp_cases c join xxcmp_requests r on r.request_id = c.request_id where c.case_id = :P211_CASE_ID""")
t += item(p, 'ASSIGNED_TO', 'selectList', 'Assigned To', 60, 'ASSIGNED_TO', region='case',
          lov=('sql', """select distinct e.full_name || ' (' || ur.user_name || ')' as display_value, ur.user_name as return_value
  from xxfnd_user_roles_v ur
  join xxfnd_employees e on e.user_name = ur.user_name
 where ur.role_code in ('COMPLIANCE_OFFICER','COMPLIANCE_MANAGER','HEAD_OF_COMPLIANCE') and ur.active_flag = 'Y'
 order by 1""", '- Unassigned -'),
          help_text='The investigating officer. A manager can reassign the case.')
t += item(p, 'RISK_TIER', 'selectList', 'Risk Classification', 70, 'RISK_TIER', region='case',
          lov=('sql', """select meaning as display_value, lookup_code as return_value from xxfnd_lookup_values
 where lookup_type = 'RISK_TIER' and enabled_flag = 'Y' order by display_sequence""", '- Not classified -'),
          help_text='Your own judgement from everything found in the investigation. The intake score is reference only.')
t += item(p, 'ENHANCED_KYC_FLAG', 'switch', 'Enhanced KYC', 80, 'ENHANCED_KYC_FLAG', region='case',
          help_text='Set automatically by a confirmed match or a PEP flag; can also be set by the officer.')
t += item(p, 'PEP_FLAG', 'displayOnly', 'PEP', 90, 'PEP_FLAG', region='case')
t += item(p, 'NEXT_REVIEW_DATE', 'displayOnly', 'Next Review', 100, 'NEXT_REVIEW_DATE', dtype='date', region='case')
t += item(p, 'CONDITIONS', 'displayOnly', 'Conditions', 110, 'CONDITIONS', region='case')
t = t.replace(f"""    pageItem P211_PARTY_ID (
        type: hidden
        layout {{
            sequence: 3
            region: @case
            slot: regionBody
        }}
    )
""", """    pageItem P211_PARTY_ID (
        type: hidden
        layout {
            sequence: 3
            region: @case
            slot: regionBody
        }
        source {
            formRegion: @case
            column: PARTY_ID
            dataType: number
        }
    )
""").replace(f"""    pageItem P211_WORKFLOW_ID (
        type: hidden
        layout {{
            sequence: 4
            region: @case
            slot: regionBody
        }}
    )
""", """    pageItem P211_WORKFLOW_ID (
        type: hidden
        layout {
            sequence: 4
            region: @case
            slot: regionBody
        }
        source {
            formRegion: @case
            column: WORKFLOW_ID
            dataType: number
        }
    )
""")
# officer questionnaire
t += '''    region findings (
        name: Investigation Questionnaire
        type: interactiveGrid
        source {
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
                select a.answer_id,
                       a.question_id,
                       (select q.section_name from xxcmp_questions q where q.question_id = a.question_id) as section_name,
                       (select q.question_text from xxcmp_questions q where q.question_id = a.question_id) as question_text,
                       a.answer_option_id,
                       a.answer_text
                  from xxcmp_request_answers a
                 where a.case_id = :P211_CASE_ID
                   and a.respondent_type = 'OFFICER'
                ```
            pageItemsToSubmit: P211_CASE_ID
        }
        layout {
            sequence: 30
            slot: BODY
        }
        appearance {
            template: @/standard
            templateOptions: #DEFAULT#
        }
        advanced {
            htmlDomId: findings
        }
        edit {
            enabled: true
            allowedOperations: [
                update
            ]
        }
        pagination {
            type: page
        }
        messages {
            whenNoDataFound: No investigation questions are configured.
        }
        toolbar {
            controls: [
                saveButton
            ]
        }

        savedReport PRIMARY (
            visibility: primary
            view {
                default: grid
            }
        )

        column APEX$ROW_SELECTOR (
            type: rowSelector
            layout {
                sequence: 5
            }
        )

        column ANSWER_ID (
            type: hidden
            layout {
                sequence: 10
            }
            source {
                type: databaseColumn
                databaseColumn: ANSWER_ID
                dataType: number
                primaryKey: true
            }
        )

        column QUESTION_ID (
            type: hidden
            layout {
                sequence: 20
            }
            source {
                type: databaseColumn
                databaseColumn: QUESTION_ID
                dataType: number
            }
        )

        column SECTION_NAME (
            type: displayOnly
            heading {
                heading: Section
            }
            layout {
                sequence: 30
            }
            source {
                type: databaseColumn
                databaseColumn: SECTION_NAME
                dataType: varchar2
                queryOnly: true
            }
        )

        column QUESTION_TEXT (
            type: displayOnly
            heading {
                heading: Question
            }
            layout {
                sequence: 40
            }
            source {
                type: databaseColumn
                databaseColumn: QUESTION_TEXT
                dataType: varchar2
                queryOnly: true
            }
        )

        column ANSWER_OPTION_ID (
            type: selectList
            heading {
                heading: Answer
            }
            layout {
                sequence: 50
            }
            lov {
                type: sqlQuery
                sqlQuery:
                    ```sql
                    select answer_label as display_value, answer_option_id as return_value
                      from xxcmp_answer_options
                     where question_id = :QUESTION_ID and approval_status = 'APPROVED' and enabled_flag = 'Y'
                     order by display_sequence
                    ```
                displayNullValue: true
                nullDisplayValue: -
            }
            cascadingLov {
                parentColumns: QUESTION_ID
            }
            source {
                type: databaseColumn
                databaseColumn: ANSWER_OPTION_ID
                dataType: number
            }
        )

        column ANSWER_TEXT (
            type: textarea
            heading {
                heading: Findings
            }
            layout {
                sequence: 60
            }
            validation {
                maxLength: 4000
            }
            source {
                type: databaseColumn
                databaseColumn: ANSWER_TEXT
                dataType: varchar2
            }
        )

    )

'''
# screenings, documents, UBO, notes, RFIs, decisions
SCREEN_URL = "apex_page.get_url(p_page => 213, p_items => 'P213_SCREENING_ID,P213_CASE_ID', p_values => to_char(s.screening_id) || ',' || :P211_CASE_ID, p_clear_cache => '213')"
t += classic('screenings', 'Screenings', f'''select s.screening_id,
       xxfnd_util_pkg.lookup_meaning('SCREENING_TYPE', s.screening_type) as screening_type,
       p.party_name,
       xxfnd_util_pkg.lookup_meaning('SCREENING_MATCH_STATUS', s.match_status) as match_status,
       rtrim(case when s.pep_flag = 'Y' then 'PEP, ' end || case when s.sanctions_flag = 'Y' then 'Sanctions, ' end
             || case when s.adverse_media_flag = 'Y' then 'Adverse media, ' end, ', ') as flags,
       s.capture_method, s.screened_date, s.result_notes,
       {SCREEN_URL} as open_url
  from xxcmp_screenings s
  join xxcmp_parties p on p.party_id = s.party_id
 where s.case_id = :P211_CASE_ID
 order by s.screened_date desc, s.screening_id desc''',
             [('SCREENING_ID', '', 'hidden'), ('SCREENING_TYPE', 'Check', 'plainText', '<a href="#OPEN_URL#">#SCREENING_TYPE#</a>'),
              ('PARTY_NAME', 'Party'), ('MATCH_STATUS', 'Result'), ('FLAGS', 'Flags'), ('CAPTURE_METHOD', 'Captured'),
              ('SCREENED_DATE', 'Date'), ('RESULT_NOTES', 'Notes'), ('OPEN_URL', '', 'hidden')], 40,
             submit='P211_CASE_ID', nodata='No screening recorded yet.')
VERIFY_URL = "apex_page.get_url(p_page => 215, p_items => 'P215_VERIFICATION_ID,P215_CASE_ID,P215_ATTACHED_DOCUMENT_ID', p_values => to_char(v.verification_id) || ',' || :P211_CASE_ID || ',' || to_char(a.attached_document_id), p_clear_cache => '215')"
t += classic('party_documents', 'Documents and Verification', f'''select a.attached_document_id,
       a.title, a.category_name, a.document_date, a.expiry_date,
       case when a.expired_flag = 'Y' then 'Expired' end as expired,
       case a.entity_name when 'XXCMP_REQUESTS' then 'Request' when 'XXCMP_CASES' then 'Case' else 'Party' end as attached_to,
       nvl(xxfnd_util_pkg.lookup_meaning('DOC_VERIFICATION_STATUS', v.verification_status), 'Not verified') as verification,
       v.notes,
       case when a.datatype_code = 'FILE' then
           apex_page.get_url(p_page => 1, p_request => 'APPLICATION_PROCESS=DOWNLOAD_DOCUMENT',
                             p_items => 'G_DOCUMENT_ID', p_values => to_char(a.document_id)) end as download_url,
       {VERIFY_URL} as verify_url
  from xxfnd_attached_documents_v a
  left join xxcmp_doc_verifications v on v.attached_document_id = a.attached_document_id and v.case_id = :P211_CASE_ID
 where (a.entity_name = 'XXCMP_PARTIES' and a.pk1_value = :P211_PARTY_ID)
    or (a.entity_name = 'XXCMP_CASES' and a.pk1_value = :P211_CASE_ID)
    or (a.entity_name = 'XXCMP_REQUESTS' and a.pk1_value = (select to_char(request_id) from xxcmp_cases where case_id = :P211_CASE_ID))
 order by a.category_name, a.creation_date''',
             [('ATTACHED_DOCUMENT_ID', '', 'hidden'), ('TITLE', 'Title', 'plainText', '<a href="#DOWNLOAD_URL#">#TITLE#</a>'),
              ('CATEGORY_NAME', 'Category'), ('ATTACHED_TO', 'On'), ('DOCUMENT_DATE', 'Dated'), ('EXPIRY_DATE', 'Expires'),
              ('EXPIRED', 'Expired'), ('VERIFICATION', 'Verification', 'plainText', '<a href="#VERIFY_URL#">#VERIFICATION#</a>'),
              ('NOTES', 'Notes'), ('DOWNLOAD_URL', '', 'hidden'), ('VERIFY_URL', '', 'hidden')], 50,
             submit='P211_CASE_ID,P211_PARTY_ID', nodata='No documents on the party, the request or the case.')
UBO_URL = "apex_page.get_url(p_page => 214, p_items => 'P214_UBO_ID,P214_CASE_ID', p_values => to_char(u.ubo_id) || ',' || :P211_CASE_ID, p_clear_cache => '214')"
t += classic('ubos', 'Beneficial Owners', f'''select u.ubo_id, p.party_name,
       xxfnd_util_pkg.lookup_meaning('UBO_BASIS', u.basis) as basis,
       u.ownership_percentage, u.notes, u.created_by,
       {UBO_URL} as open_url
  from xxcmp_ubo_determinations u
  join xxcmp_parties p on p.party_id = u.owner_party_id
 where u.case_id = :P211_CASE_ID
 order by u.ownership_percentage desc nulls last''',
             [('UBO_ID', '', 'hidden'), ('PARTY_NAME', 'Beneficial Owner', 'plainText', '<a href="#OPEN_URL#">#PARTY_NAME#</a>'),
              ('BASIS', 'Basis'), ('OWNERSHIP_PERCENTAGE', 'Ownership %'), ('NOTES', 'Notes'), ('CREATED_BY', 'Determined By'),
              ('OPEN_URL', '', 'hidden')], 60, submit='P211_CASE_ID', nodata='No beneficial owner determined yet.')
t += classic('notes', 'Investigation Notes', '''select n.note_text, p.party_name as about, n.created_by, n.creation_date
  from xxcmp_case_notes n
  left join xxcmp_parties p on p.party_id = n.related_party_id
 where n.case_id = :P211_CASE_ID
 order by n.creation_date desc''',
             [('NOTE_TEXT', 'Note'), ('ABOUT', 'About'), ('CREATED_BY', 'By'), ('CREATION_DATE', 'When')], 70,
             submit='P211_CASE_ID', nodata='No notes yet.')
t += pitem(p, 'NEW_NOTE', 'textarea', 'New Note', 10, 'notes', max_len=4000, height=2, condition=IS_OPEN)
t += classic('rfis', 'Requests for Information', '''select r.rfi_id, r.rfi_number,
       xxfnd_util_pkg.lookup_meaning('RFI_CATEGORY', r.rfi_category) as category,
       xxfnd_util_pkg.lookup_meaning('RFI_STATUS', r.rfi_status) as status,
       case r.continue_other_work_flag when 'N' then 'Pauses the case' end as blocking,
       r.due_date, r.responded_date,
       apex_page.get_url(p_page => 31, p_items => 'P31_RFI_ID', p_values => to_char(r.rfi_id), p_clear_cache => '31') as open_url
  from xxcmp_rfis r
 where (r.entity_name = 'XXCMP_CASES' and r.pk1_value = :P211_CASE_ID)
    or (r.entity_name = 'XXCMP_REQUESTS' and r.pk1_value = (select to_char(request_id) from xxcmp_cases where case_id = :P211_CASE_ID))
 order by r.rfi_id desc''',
             [('RFI_ID', '', 'hidden'), ('RFI_NUMBER', 'RFI', 'plainText', '<a href="#OPEN_URL#">#RFI_NUMBER#</a>'),
              ('CATEGORY', 'Category'), ('STATUS', 'Status'), ('BLOCKING', 'Effect'), ('DUE_DATE', 'Due'),
              ('RESPONDED_DATE', 'Answered'), ('OPEN_URL', '', 'hidden')], 80, submit='P211_CASE_ID',
             nodata='No requests for information.')
t += classic('decisions', 'Decisions', '''select d.level_no, initcap(d.outcome) as outcome,
       r.role_name, d.decided_by, to_char(d.decision_date, 'DD-Mon-YYYY HH24:MI') as decision_date, d.comments
  from xxcmp_case_decisions d
  left join xxfnd_roles r on r.role_code = d.role_code
 where d.case_id = :P211_CASE_ID
 order by d.decision_date''',
             [('LEVEL_NO', 'Level'), ('OUTCOME', 'Outcome'), ('ROLE_NAME', 'As'),
              ('DECIDED_BY', 'By'), ('DECISION_DATE', 'When'), ('COMMENTS', 'Comments')], 90, submit='P211_CASE_ID',
             nodata='No decision yet.')
t += '''    region workflow-diagram (
        name: Workflow
        type: workflowDiagram
        layout {
            sequence: 100
            slot: BODY
        }
        appearance {
            template: @/collapsible
            templateOptions: [
                #DEFAULT#
                is-collapsed
                t-Region--scrollBody
            ]
        }
        settings {
            workflowId: P211_WORKFLOW_ID
        }
        serverSideCondition {
            type: itemIsNotNull
            item: P211_WORKFLOW_ID
        }
    )

'''
# buttons
t += button('save', 'SAVE', 'Save', 10, 'buttons', 'EDIT', condition=IS_OPEN, auth='page-manage')
t += button('submit-approval', 'SUBMIT_APPROVAL', 'Submit for Approval', 20, 'buttons', 'NEXT', hot=True,
            condition=IS_OPEN, auth='page-manage', confirm='Submit the case for approval? It can no longer be changed.')
t += button('raise-rfi', 'RAISE_RFI', 'Raise RFI', 5, 'rfis', 'EDIT', action='redirectThisApp',
            target='page: 32\nitems: {\n    P32_ENTITY_NAME: XXCMP_CASES\n    P32_PK1_VALUE: &P211_CASE_ID.\n}\nclearCache: 32',
            condition=IS_OPEN, auth='page-manage', validations=False)
t += button('add-screening', 'ADD_SCREENING', 'Add Screening', 5, 'screenings', 'EDIT', action='redirectThisApp',
            target='page: 213\nitems: {\n    P213_CASE_ID: &P211_CASE_ID.\n}\nclearCache: 213',
            condition=IS_OPEN, auth='page-manage', validations=False)
t += button('add-ubo', 'ADD_UBO', 'Add Beneficial Owner', 5, 'ubos', 'EDIT', action='redirectThisApp',
            target='page: 214\nitems: {\n    P214_CASE_ID: &P211_CASE_ID.\n}\nclearCache: 214',
            condition=IS_OPEN, auth='page-manage', validations=False)
t += button('party_documents-add', 'PARTY_DOCUMENTS_ADD', 'Add Document', 5, 'party_documents', 'EDIT', action='redirectThisApp',
            target='page: 90\nitems: {\n    P90_ENTITY_NAME: XXCMP_PARTIES\n    P90_PK1_VALUE: &P211_PARTY_ID.\n    P90_SOURCE_PAGE: 211\n    P90_SOURCE_REGION: party_documents\n}\nclearCache: 90',
            condition="type: expression\nlanguage: plsql\nplsqlExpression:\n    ```plsql\n    xxfnd_attach_pkg.block_permission(:APP_ALIAS, 211, 'party_documents', 'XXCMP_PARTIES', 'INSERT') = 'Y'\n    ```",
            validations=False)
t += button('add-note', 'ADD_NOTE', 'Add Note', 5, 'notes', 'EDIT', condition=IS_OPEN, auth='page-manage')
t += button('report', 'REPORT', 'Compliance Report', 30, 'buttons', 'EDIT', action='redirectThisApp',
            target='page: 217\nitems: {\n    P217_CASE_ID: &P211_CASE_ID.\n}\nclearCache: 217',
            condition="type: rowsReturned\nsqlQuery:\n    ```sql\n    select 1 from xxcmp_cases where case_id = :P211_CASE_ID and closed_date is not null\n    ```",
            validations=False)
for rid in ('screenings', 'ubos', 'party_documents'):
    t += refresh_da(rid, {'screenings': 40, 'ubos': 50, 'party_documents': 60}[rid])
t += fn_validation('submit-check', 'Case complete', 'return xxcmp_case_pkg.submit_error(:P211_CASE_ID);',
                   'P211_RISK_TIER', requests='SUBMIT_APPROVAL')
t += fn_validation('note-text', 'Note entered', "return case when :P211_NEW_NOTE is null then 'Enter the note.' end;",
                   'P211_NEW_NOTE', requests='ADD_NOTE')
t += process('open-from-task', 'Open from task', '''select to_number(detail_pk) into :P211_CASE_ID
  from table ( apex_human_task.get_tasks (
                   p_context        => 'SINGLE_TASK',
                   p_task_id        => :P211_TASK_ID,
                   p_application_id => :APP_ID ) )
 where task_def_static_id = 'CASE_INVESTIGATION';''', 5, point='beforeHeader',
             condition='type: itemIsNotNull\nitem: P211_TASK_ID')
t += '''    process initialize-form (
        name: Initialize form
        type: formInitialization
        formRegion: @case
        execution {
            sequence: 10
            point: beforeHeader
        }
    )

    process process-form (
        name: Save case
        type: formAutoRowProcessing
        formRegion: @case
        execution {
            sequence: 10
            point: processing
        }
        successMessage {
            successMessage: Case saved.
        }
        serverSideCondition {
            type: requestIsContainedInValue
            value: SAVE,SUBMIT_APPROVAL
        }
        security {
            authorizationScheme: @page-submit
        }
    )

    process save-findings (
        name: Save questionnaire
        type: interactiveGridAutoRowProcessing
        editableRegion: @findings
        execution {
            sequence: 15
            point: processing
        }
        security {
            authorizationScheme: @page-submit
        }
    )

'''
t += process('apply-screening', 'Enhanced KYC from screening', 'xxcmp_case_pkg.apply_screening(:P211_CASE_ID);', 18,
             requests='SAVE,SUBMIT_APPROVAL', auth='page-submit')
t += process('submit-for-approval', 'Submit for approval', 'xxcmp_case_pkg.submit_for_approval(:P211_CASE_ID);', 20,
             button_='submit-approval', auth='page-submit', success='Case submitted for approval.')
t += process('add-note', 'Add note', '''insert into xxcmp_case_notes (case_id, note_text) values (:P211_CASE_ID, :P211_NEW_NOTE);
:P211_NEW_NOTE := null;''', 30, button_='add-note', auth='page-submit', success='Note added.')
t += ')\n'
write('p00211-case.apx', t)

# ===================================================================== 212
p = 212
t = page_header(p, 'Case Decision', 'CASE-DECISION', 'kyc',
                'Approve or reject one approval level of a case. The investigating officer and earlier approvers cannot decide; '
                'a Suspicious Activity Report determination is required where the approval matrix asks for it; every mandatory document '
                'must be verified.', modal=True, width=900)
t += static_region('decision', 'Case Decision', 10, slot='contentBody', template='blank-with-attributes')
t += static_region('buttons', 'Buttons', 90, slot='REGION_POSITION_03', template='buttons-container')
t += pitem(p, 'TASK_ID', 'hidden', None, 1, 'decision', protect=True)
t += pitem(p, 'CASE_ID', 'hidden', None, 2, 'decision', protect=False)
t += pitem(p, 'SAR_GATE', 'hidden', None, 3, 'decision', protect=False)
for i, (name, label, sql) in enumerate([
        ('CASE', 'Case', """select c.case_number || ' - ' || p.party_name || ' (' || p.party_number || ')'
  from xxcmp_cases c join xxcmp_parties p on p.party_id = c.party_id where c.case_id = :P212_CASE_ID"""),
        ('LEVEL', 'Approval Level', """select c.current_level || ' of ' || xxcmp_case_pkg.required_levels(c.case_id)
       || ' - ' || (select role_name from xxfnd_roles where role_code = xxcmp_case_pkg.level_role(c.case_id, c.current_level))
  from xxcmp_cases c where c.case_id = :P212_CASE_ID"""),
        ('RISK', 'Risk', """select xxfnd_util_pkg.lookup_meaning('RISK_TIER', risk_tier)
       || case when enhanced_kyc_flag = 'Y' then ' - Enhanced KYC' end || case when pep_flag = 'Y' then ' - PEP' end
  from xxcmp_cases where case_id = :P212_CASE_ID"""),
        ('INVESTIGATOR', 'Investigated By', "select assigned_to from xxcmp_cases where case_id = :P212_CASE_ID"),
        ('SCREENING', 'Screening', """select count(*) || ' check(s); ' || count(case when match_status = 'CONFIRMED_MATCH' then 1 end) || ' confirmed match(es); '
       || count(case when pep_flag = 'Y' then 1 end) || ' PEP flag(s)'
  from xxcmp_screenings where case_id = :P212_CASE_ID"""),
        ('READINESS', 'Ready to Approve', "select nvl(xxcmp_case_pkg.approval_error(:P212_CASE_ID), 'Yes') from dual")]):
    t += pitem(p, name, 'displayOnly', label, (i + 1) * 10, 'decision', sql=sql)
t += pitem(p, 'SAR_REQUIRED_FLAG', 'radioGroup', 'Suspicious Activity Report Required', 70, 'decision',
           lov=('sql', "select 'Yes' as display_value, 'Y' as return_value from dual union all select 'No', 'N' from dual", None),
           help_text='Required before approval for high-risk and Enhanced KYC cases.')
t += pitem(p, 'SAR_NOTES', 'textarea', 'SAR Notes', 80, 'decision', max_len=4000, height=2)
t += pitem(p, 'CONDITIONS', 'textarea', 'Conditions of Approval', 90, 'decision', max_len=4000, height=2)
t += pitem(p, 'NEXT_REVIEW_DATE', 'datePicker', 'Next Review Date', 100, 'decision',
           help_text='Calculated from the risk tier (sooner for a PEP); change it only with a reason in the comment.')
t += pitem(p, 'COMMENT', 'textarea', 'Comment', 110, 'decision', max_len=1000, height=2,
           help_text='Recorded with the decision; required when rejecting.')
TASK_OK = "type: expression\nlanguage: plsql\nplsqlExpression:\n    ```plsql\n    apex_human_task.is_allowed(p_task_id => :P212_TASK_ID, p_operation => apex_human_task.c_task_op_approve)\n    or apex_human_task.is_allowed(p_task_id => :P212_TASK_ID, p_operation => apex_human_task.c_task_op_claim)\n    ```"
t += button('cancel', 'CANCEL', 'Cancel', 10, 'buttons', 'CLOSE', action='definedByDynamicAction')
t += button('reject', 'REJECT', 'Reject', 20, 'buttons', 'DELETE', condition=TASK_OK, confirm='Reject this case?')
t += button('approve', 'APPROVE', 'Approve', 30, 'buttons', 'NEXT', hot=True, condition=TASK_OK)
t += '''    dynamicAction cancel-dialog (
        name: Cancel Dialog
        execution {
            sequence: 10
        }
        when {
            event: click
            selectionType: button
            button: @cancel
        }

        action cancel-dialog-action (
            action: cancelDialog
            execution {
                sequence: 10
                fireOnInit: false
            }
        )

    )

'''
t += process('load-task', 'Load case', '''select to_number(detail_pk) into :P212_CASE_ID
  from table ( apex_human_task.get_tasks (
                   p_context        => 'SINGLE_TASK',
                   p_task_id        => :P212_TASK_ID,
                   p_application_id => :APP_ID ) )
 where task_def_static_id = 'CASE_APPROVAL';
select sar_required_flag, sar_notes, conditions,
       to_char(nvl(next_review_date, xxcmp_case_pkg.next_review_date(case_id)), 'DD-MON-YYYY'),
       xxcmp_case_pkg.sar_gate(case_id)
  into :P212_SAR_REQUIRED_FLAG, :P212_SAR_NOTES, :P212_CONDITIONS, :P212_NEXT_REVIEW_DATE, :P212_SAR_GATE
  from xxcmp_cases where case_id = :P212_CASE_ID;''', 5, point='beforeHeader')
t += fn_validation('reject-reason', 'Reason for rejection',
                   "return case when :P212_COMMENT is null then 'Enter why the case is rejected.' end;", 'P212_COMMENT',
                   requests='REJECT')
t += fn_validation('sar-answered', 'SAR determination',
                   "return case when :P212_SAR_GATE = 'Y' and :P212_SAR_REQUIRED_FLAG is null then 'Record whether a Suspicious Activity Report is required.' end;",
                   'P212_SAR_REQUIRED_FLAG', seq=20, requests='APPROVE')
t += process('save-decision-data', 'Save SAR, conditions and review date', '''update xxcmp_cases
   set sar_required_flag = :P212_SAR_REQUIRED_FLAG,
       sar_notes         = :P212_SAR_NOTES,
       conditions        = :P212_CONDITIONS,
       next_review_date  = to_date(:P212_NEXT_REVIEW_DATE, 'DD-MON-YYYY')
 where case_id = :P212_CASE_ID;''', 10, requests='APPROVE,REJECT')
t += process('check-approval', 'Check the case can be approved', '''declare
    l_error varchar2(4000) := xxcmp_case_pkg.approval_error(:P212_CASE_ID);
begin
    if l_error is not null then
        raise_application_error(-20615, l_error);
    end if;
end;''', 15, button_='approve')
t += process('add-comment', 'Record comment', 'apex_human_task.add_task_comment(p_task_id => :P212_TASK_ID, p_text => :P212_COMMENT);',
             20, condition='type: itemIsNotNull\nitem: P212_COMMENT')
t += process('approve-task', 'Approve', 'apex_human_task.approve_task(p_task_id => :P212_TASK_ID, p_autoclaim => true);',
             30, button_='approve', success='Case approved at this level.')
t += process('reject-task', 'Reject', 'apex_human_task.reject_task(p_task_id => :P212_TASK_ID, p_autoclaim => true);',
             40, button_='reject', success='Case rejected.')
t += close_dialog('APPROVE,REJECT')
t += ')\n'
write('p00212-case-decision.apx', t)

# ===================================================================== 213-216 drawers
CASE_PARTIES = """select p.party_name || ' (' || p.party_number || ')' as display_value, p.party_id as return_value
  from xxcmp_parties p
 where p.party_id = (select c.party_id from xxcmp_cases c where c.case_id = :P{n}_CASE_ID)
    or p.party_id in (select r.object_party_id from xxcmp_party_relationships r
                       where r.subject_party_id = (select c.party_id from xxcmp_cases c where c.case_id = :P{n}_CASE_ID)
                         and (r.end_date is null or r.end_date >= trunc(sysdate)))
 order by 1"""
write('p00213-screening.apx', form_page(
    213, 'Screening', 'SCREENING', 'kyc',
    'One screening check (registry, sanctions, PEP or adverse media) on the party or a related party. A confirmed match or a PEP flag puts the case into Enhanced KYC.',
    'XXCMP_SCREENINGS', 'SCREENING_ID',
    [item(213, 'SCREENING_ID', 'hidden', None, 1, 'SCREENING_ID', dtype='number', pk=True),
     item(213, 'CASE_ID', 'hidden', None, 2, 'CASE_ID', dtype='number'),
     item(213, 'PARTY_ID', 'selectList', 'Party', 10, 'PARTY_ID', dtype='number', required=True,
          lov=('sql', CASE_PARTIES.replace('{n}', '213'), '- Select -'), help_text='The party or a related party of the case.',
          default_sql='select party_id from xxcmp_cases where case_id = :P213_CASE_ID'),
     item(213, 'SCREENING_TYPE', 'selectList', 'Check', 20, 'SCREENING_TYPE', required=True, lov=lookup_lov('SCREENING_TYPE')),
     item(213, 'MATCH_STATUS', 'selectList', 'Result', 30, 'MATCH_STATUS', required=True, lov=lookup_lov('SCREENING_MATCH_STATUS', None),
          default='NO_MATCH'),
     item(213, 'PEP_FLAG', 'switch', 'PEP', 40, 'PEP_FLAG', default='N'),
     item(213, 'SANCTIONS_FLAG', 'switch', 'Sanctions', 50, 'SANCTIONS_FLAG', default='N'),
     item(213, 'ADVERSE_MEDIA_FLAG', 'switch', 'Adverse Media', 60, 'ADVERSE_MEDIA_FLAG', default='N'),
     item(213, 'SCREENED_DATE', 'datePicker', 'Screened On', 70, 'SCREENED_DATE', dtype='date', required=True,
          default_sql='select trunc(sysdate) from dual'),
     item(213, 'SOURCE_REFERENCE', 'textField', 'Source / Reference', 80, 'SOURCE_REFERENCE', max_len=1000),
     item(213, 'RESULT_NOTES', 'textarea', 'Notes', 90, 'RESULT_NOTES', max_len=4000, height=3),
     item(213, 'CAPTURE_METHOD', 'displayOnly', 'Captured', 100, 'CAPTURE_METHOD', default='MANUAL')],
    extra_processes='''    process apply-screening (
        name: Enhanced KYC from screening
        type: executeCode
        source {
            language: plsql
            plsqlCode:
                ```plsql
                xxcmp_case_pkg.apply_screening(:P213_CASE_ID);
                ```
        }
        execution {
            sequence: 20
            point: processing
        }
        serverSideCondition {
            type: requestIsContainedInValue
            value: CREATE,SAVE,DELETE
        }
        security {
            authorizationScheme: @page-submit
        }
    )

'''))
write('p00214-beneficial-owner.apx', form_page(
    214, 'Beneficial Owner', 'BENEFICIAL-OWNER', 'kyc',
    'Your determination of a beneficial owner for this case: on ownership, control, or the documented fallback basis. The ownership chain is reference only.',
    'XXCMP_UBO_DETERMINATIONS', 'UBO_ID',
    [item(214, 'UBO_ID', 'hidden', None, 1, 'UBO_ID', dtype='number', pk=True),
     item(214, 'CASE_ID', 'hidden', None, 2, 'CASE_ID', dtype='number'),
     item(214, 'OWNER_PARTY_ID', 'selectList', 'Beneficial Owner', 10, 'OWNER_PARTY_ID', dtype='number', required=True,
          lov=('sql', CASE_PARTIES.replace('{n}', '214'), '- Select -'),
          help_text='A related party of the case party (add related parties on the party first).'),
     item(214, 'BASIS', 'selectList', 'Basis', 20, 'BASIS', required=True, lov=lookup_lov('UBO_BASIS')),
     item(214, 'OWNERSHIP_PERCENTAGE', 'numberField', 'Ownership %', 30, 'OWNERSHIP_PERCENTAGE', dtype='number'),
     item(214, 'NOTES', 'textarea', 'Notes', 40, 'NOTES', max_len=4000, height=3)]))
write('p00215-document-verification.apx', form_page(
    215, 'Document Verification', 'DOCUMENT-VERIFICATION', 'kyc',
    'Whether this document is genuine and current, as checked for this case.',
    'XXCMP_DOC_VERIFICATIONS', 'VERIFICATION_ID',
    [item(215, 'VERIFICATION_ID', 'hidden', None, 1, 'VERIFICATION_ID', dtype='number', pk=True),
     item(215, 'CASE_ID', 'hidden', None, 2, 'CASE_ID', dtype='number'),
     item(215, 'ATTACHED_DOCUMENT_ID', 'hidden', None, 3, 'ATTACHED_DOCUMENT_ID', dtype='number'),
     item(215, 'VERIFICATION_STATUS', 'selectList', 'Status', 10, 'VERIFICATION_STATUS', required=True,
          lov=lookup_lov('DOC_VERIFICATION_STATUS')),
     item(215, 'NOTES', 'textarea', 'Notes', 20, 'NOTES', max_len=4000, height=3)], delete=False))
# 216 new case: not a table form
p = 216
t = page_header(p, 'Create Case', 'CREATE-CASE', 'kyc',
                'Open a case for a party without an intake request, e.g. on information received. A request is recorded for the audit trail.',
                modal=True)
t += static_region('new_case', 'Create Case', 10, slot='contentBody', template='blank-with-attributes')
t += static_region('buttons', 'Buttons', 90, slot='REGION_POSITION_03', template='buttons-container')
t += pitem(p, 'PARTY_ID', 'selectList', 'Party', 10, 'new_case', required=True,
           lov=('sql', """select party_name || ' (' || party_number || ')' as display_value, party_id as return_value
  from xxcmp_parties where enabled_flag = 'Y' order by party_name""", '- Select -'))
t += pitem(p, 'JUSTIFICATION', 'textarea', 'Reason', 20, 'new_case', required=True, max_len=4000, height=3)
t += button('cancel', 'CANCEL', 'Cancel', 10, 'buttons', 'CLOSE', action='definedByDynamicAction')
t += button('create', 'CREATE', 'Create Case', 20, 'buttons', 'CREATE', hot=True, auth='page-create')
t += '''    dynamicAction cancel-dialog (
        name: Cancel Dialog
        execution {
            sequence: 10
        }
        when {
            event: click
            selectionType: button
            button: @cancel
        }

        action cancel-dialog-action (
            action: cancelDialog
            execution {
                sequence: 10
                fireOnInit: false
            }
        )

    )

'''
t += process('create-case', 'Create case', '''declare
    l_case number;
begin
    l_case := xxcmp_case_pkg.create_manual_case(to_number(:P216_PARTY_ID), :P216_JUSTIFICATION);
end;''', 10, button_='create', auth='page-submit', success='Case created.')
t += close_dialog('CREATE')
t += ')\n'
write('p00216-create-case.apx', t)

# ===================================================================== 217 compliance report
p = 217
t = page_header(p, 'Compliance Report', 'COMPLIANCE-REPORT', 'kyc',
                'The report of a closed case: intake, investigation and approval trail with the conclusion for its risk tier. Print it from the browser.')
t += breadcrumb_region('Compliance Report') + '\n'
t += static_region('report', 'Compliance Report', 20)
t += pitem(p, 'CASE_ID', 'hidden', None, 1, 'report', protect=True)
for i, (name, label, sql) in enumerate([
        ('CASE', 'Case', """select c.case_number || ' - closed ' || to_char(c.closed_date, 'DD-Mon-YYYY') from xxcmp_cases c where c.case_id = :P217_CASE_ID"""),
        ('PARTY', 'Party', """select p.party_number || ' - ' || p.party_name || nvl2(p.registration_number, ' - ' || p.registration_number, null)
       || nvl2(p.jurisdiction, ' - ' || xxfnd_util_pkg.lookup_meaning('JURISDICTION', p.jurisdiction), null)
  from xxcmp_cases c join xxcmp_parties p on p.party_id = c.party_id where c.case_id = :P217_CASE_ID"""),
        ('DECISION', 'Decision', """select c.decision || ' - risk ' || xxfnd_util_pkg.lookup_meaning('RISK_TIER', c.risk_tier)
       || case when c.enhanced_kyc_flag = 'Y' then ' - Enhanced KYC' end || case when c.pep_flag = 'Y' then ' - PEP' end
       || ' - next review ' || to_char(c.next_review_date, 'DD-Mon-YYYY')
  from xxcmp_cases c where c.case_id = :P217_CASE_ID"""),
        ('CONDITIONS', 'Conditions', "select conditions from xxcmp_cases where case_id = :P217_CASE_ID"),
        ('CONCLUSION', 'Conclusion', """select xxfnd_util_pkg.replace_tokens(t.template_text,
           json_object('PARTY_NAME' value p.party_name, 'REQUEST_NUMBER' value r.request_number,
                       'RISK_TIER' value xxfnd_util_pkg.lookup_meaning('RISK_TIER', c.risk_tier),
                       'RISK_FACTORS' value nvl((select listagg(xxfnd_util_pkg.lookup_meaning('SCREENING_TYPE', s.screening_type), ', ')
                                                   from xxcmp_screenings s where s.case_id = c.case_id
                                                    and (s.match_status = 'CONFIRMED_MATCH' or s.pep_flag = 'Y' or s.sanctions_flag = 'Y' or s.adverse_media_flag = 'Y')), 'none')))
  from xxcmp_cases c
  join xxcmp_parties p on p.party_id = c.party_id
  join xxcmp_requests r on r.request_id = c.request_id
  left join xxcmp_conclusion_templates t on t.risk_tier = c.risk_tier and t.enabled_flag = 'Y'
 where c.case_id = :P217_CASE_ID""")]):
    t += pitem(p, name, 'displayOnly', label, (i + 1) * 10, 'report', sql=sql)
t += classic('trail', 'Approval Trail', '''select d.level_no, initcap(d.outcome) as outcome, r.role_name, d.decided_by,
       to_char(d.decision_date, 'DD-Mon-YYYY HH24:MI') as decision_date, d.comments
  from xxcmp_case_decisions d left join xxfnd_roles r on r.role_code = d.role_code
 where d.case_id = :P217_CASE_ID order by d.decision_date''',
             [('LEVEL_NO', 'Level'), ('OUTCOME', 'Outcome'), ('ROLE_NAME', 'As'), ('DECIDED_BY', 'By'),
              ('DECISION_DATE', 'When'), ('COMMENTS', 'Comments')], 30, submit='P217_CASE_ID')
t += classic('screening_summary', 'Screening', '''select xxfnd_util_pkg.lookup_meaning('SCREENING_TYPE', s.screening_type) as check_type, p.party_name,
       xxfnd_util_pkg.lookup_meaning('SCREENING_MATCH_STATUS', s.match_status) as result, s.screened_date, s.result_notes
  from xxcmp_screenings s join xxcmp_parties p on p.party_id = s.party_id
 where s.case_id = :P217_CASE_ID order by s.screened_date''',
             [('CHECK_TYPE', 'Check'), ('PARTY_NAME', 'Party'), ('RESULT', 'Result'), ('SCREENED_DATE', 'Date'),
              ('RESULT_NOTES', 'Notes')], 40, submit='P217_CASE_ID')
t += ')\n'
write('p00217-compliance-report.apx', t)
print('chunk 5 pages written')

# interactive grids: list the shown columns in the primary report
import subprocess
subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'ig_display_columns.py')], check=True)
