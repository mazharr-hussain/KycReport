#!/usr/bin/env python3
"""Page building blocks shared by the chunk generators (on top of pagegen.py): page header with optional
read-only condition, static and classic report regions, non-form items, buttons, processes, dialogs, branches,
wizard progress, lookup LOVs."""
import os

PAGES = os.path.join(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), 'src', 'database', 'xxcus', 'apex_apps', 'f101'), 'pages')


def write(name, text):
    with open(os.path.join(PAGES, name), 'w') as f:
        f.write(text)


def ind(text, n):
    return '\n'.join((' ' * n + l) if l.strip() else '' for l in text.strip('\n').split('\n'))


def lookup_lov(ltype, null='- Select -'):
    return ('sql', f"""select meaning as display_value, lookup_code as return_value
  from xxfnd_lookup_values
 where lookup_type = '{ltype}' and enabled_flag = 'Y'
 order by display_sequence, meaning""", null)


# ------------------------------------------------------------------ helpers
def page_header(pid, name, alias, group, help_text, modal=False, width=None, read_only=None):
    if modal:
        wdt = f'\n        width: {width}' if width else ''
        app = f'''    appearance {{
        pageMode: modalDialog
        dialogTemplate: @/drawer
        templateOptions: [
            #DEFAULT#
            js-dialog-class-t-Drawer--pullOutEnd
        ]
    }}
    dialog {{{wdt}
        chained: false
    }}'''
    else:
        app = '''    appearance {
        pageTemplate: @/standard
        templateOptions: #DEFAULT#
    }'''
    ro = f'''    readOnly {{
        type: expression
        language: plsql
        plsqlExpression:
            ```plsql
            {read_only}
            ```
    }}
''' if read_only else ''
    return f'''page {pid} (
    name: {name}
    alias: {alias}
    title: {name}
    pageGroup: @{group}
{app}
{ro}    security {{
        authorizationScheme: @page-view
        pageAccessProtection: argumentsMustHaveChecksum
        formAutoComplete: false
    }}
    help {{
        helpText:
            ```
            {help_text}
            ```
    }}

'''


def static_region(rid, name, seq, slot='BODY', template='standard', html=None, condition=None, parent=None, options=None):
    src = ''
    if html:
        src = f'''        source {{
            htmlCode:
                ```html
{ind(html, 16)}
                ```
        }}
'''
    cond = f'''        serverSideCondition {{
{ind(condition, 12)}
        }}
''' if condition else ''
    par = f'\n            parentRegion: @{parent}' if parent else ''
    opts = '#DEFAULT#' if not options else '[\n                #DEFAULT#\n' + ''.join(f'                {o}\n' for o in options) + '            ]'
    return f'''    region {rid} (
        name: {name}
        type: staticContent
{src}        layout {{
            sequence: {seq}
            slot: {slot}{par}
        }}
        appearance {{
            template: @/{template}
            templateOptions: {opts}
        }}
        advanced {{
            htmlDomId: {rid}
        }}
{cond}    )

'''


def pitem(p, name, kind, label, seq, region, required=False, lov=None, help_text=None, max_len=None,
          default=None, height=None, protect=False, sql=None, send=True, ro=None, condition=None,
          mark_required=False):
    """A page item that is not bound to a form region."""
    iname = f'P{p}_{name}'
    if kind == 'hidden':
        prot = '''
        security {
            sessionStateProtection: checksumRequiredSessionLevel
        }''' if protect else ''
        return f'''    pageItem {iname} (
        type: hidden
        layout {{
            sequence: {seq}
            region: @{region}
            slot: regionBody
        }}{prot}
    )

'''
    parts = [f'''    pageItem {iname} (
        type: {kind}
        label {{
            label: {label}
            alignment: left
        }}
''']
    if lov:
        k, v, nul = lov
        if k == 'shared':
            body = f'            type: sharedComponent\n            lov: @{v}'
        else:
            body = f'            type: sqlQuery\n            sqlQuery:\n                ```sql\n{ind(v, 16)}\n                ```'
        if nul:
            body += f'\n            displayNullValue: true\n            nullDisplayValue: {nul}'
        else:
            body += '\n            displayNullValue: false'   # APEX's default is Yes: radio groups get an empty choice
        parts.append(f'        lov {{\n{body}\n        }}\n')
    hgt = f'\n            height: {height}' if height else ''
    parts.append(f'''        layout {{
            sequence: {seq}
            region: @{region}
            slot: regionBody
            alignment: left
        }}
        appearance {{
            template: @/{'required' if required or mark_required else 'optional'}-floating
            templateOptions: #DEFAULT#{hgt}
        }}
''')
    val = []
    if required:
        val.append('            valueRequired: true')
    if max_len:
        val.append(f'            maxLength: {max_len}')
    if val:
        parts.append('        validation {\n' + '\n'.join(val) + '\n        }\n')
    if kind == 'displayOnly' or not send:
        parts.append('        settings {\n            sendOnPageSubmit: false\n        }\n')
    if sql:
        parts.append(f'''        source {{
            type: sqlQuerySingleValue
            sqlQuery:
                ```sql
{ind(sql, 16)}
                ```
            used: always
        }}
''')
    if default is not None:
        parts.append(f'''        default {{
            type: static
            staticValue: {default}
        }}
''')
    if ro:
        parts.append(f'''        readOnly {{
            type: expression
            language: plsql
            plsqlExpression:
                ```plsql
                {ro}
                ```
        }}
''')
    if help_text:
        parts.append(f'        help {{\n            helpText: {help_text}\n        }}\n')
    if condition:
        parts.append(f'        serverSideCondition {{\n{ind(condition, 12)}\n        }}\n')
    parts.append('    )\n\n')
    return ''.join(parts)


def button(bid, name, label, seq, region, slot, action='submitPage', hot=False, target=None, condition=None,
           auth=None, confirm=None, validations=True):
    beh = f'            action: {action}\n'
    if target:
        beh += f'            target: {{\n{ind(target, 16)}\n            }}\n'
    if action != 'definedByDynamicAction':
        beh += '            warnOnUnsavedChanges: doNotCheck\n'
    if not validations and action in ('submitPage', 'redirectUrl', 'definedByDynamicAction'):
        beh += '            executeValidations: false\n'
    if confirm:
        beh += '            requiresConfirmation: true\n'
    conf = f'''        confirmation {{
            message: {confirm}
        }}
''' if confirm else ''
    cond = f'''        serverSideCondition {{
{ind(condition, 12)}
        }}
''' if condition else ''
    sec = f'''        security {{
            authorizationScheme: @{auth}
        }}
''' if auth else ''
    return f'''    button {bid} (
        buttonName: {name}
        label: {label}
        layout {{
            sequence: {seq}
            region: @{region}
            slot: {slot}
        }}
        appearance {{
            buttonTemplate: @/text
{'            hot: true' + chr(10) if hot else ''}            templateOptions: #DEFAULT#
        }}
        behavior {{
{beh}        }}
{conf}{cond}{sec}    )

'''


def process(pid_name, name, plsql, seq, point='processing', button_=None, requests=None, condition=None,
            auth=None, success=None):
    cond = ''
    if button_:
        cond = f'        serverSideCondition {{\n            whenButtonPressed: @{button_}\n        }}\n'
    elif requests:
        cond = f'        serverSideCondition {{\n            type: requestIsContainedInValue\n            value: {requests}\n        }}\n'
    elif condition:
        cond = f'        serverSideCondition {{\n{ind(condition, 12)}\n        }}\n'
    sec = f'        security {{\n            authorizationScheme: @{auth}\n        }}\n' if auth else ''
    succ = f'        successMessage {{\n            successMessage: {success}\n        }}\n' if success else ''
    return f'''    process {pid_name} (
        name: {name}
        type: executeCode
        source {{
            language: plsql
            plsqlCode:
                ```plsql
{ind(plsql, 16)}
                ```
        }}
        execution {{
            sequence: {seq}
            point: {point}
        }}
{succ}{cond}{sec}    )

'''


def close_dialog(requests, seq=90):
    return f'''    process close-dialog (
        name: Close Dialog
        type: closeDialog
        execution {{
            sequence: {seq}
            point: processing
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: {requests}
        }}
    )

'''


def branch(name, page, items, seq=10, button_=None):
    its = ''.join(f'                    {k}: {v}\n' for k, v in items.items())
    items_block = f'\n                items: {{\n{its}                }}' if items else ''
    cond = f'        serverSideCondition {{\n            whenButtonPressed: @{button_}\n        }}\n' if button_ else ''
    return f'''    branch (
        name: {name}
        execution {{
            sequence: {seq}
        }}
        behavior {{
            target: {{
                page: {page}{items_block}
                clearCache: {page}
            }}
        }}
{cond}    )

'''


def classic(rid, name, sql, columns, seq, slot='BODY', submit=None, nodata='No data found.', parent=None, condition=None,
            badges=False):
    """Classic report; badges=True shows one row as Universal Theme badges (key figures)."""
    if submit and ',' in submit:   # several items: APEXlang list
        sub = '\n            pageItemsToSubmit: [\n' + ''.join(f'                {x.strip()}\n' for x in submit.split(',')) + '            ]'
    else:
        sub = f'\n            pageItemsToSubmit: {submit}' if submit else ''
    par = f'\n            parentRegion: @{parent}' if parent else ''
    cond = f'''        serverSideCondition {{
{ind(condition, 12)}
        }}
''' if condition else ''
    cols = ''
    for i, c in enumerate(columns):
        cname, heading = c[0], c[1]
        kind = c[2] if len(c) > 2 else 'plainText'
        extra = ''
        if len(c) > 3 and c[3]:
            extra = f'''            columnFormatting {{
                htmlExpression:
                    ```html
                    {c[3]}
                    ```
            }}
'''
        if kind == 'hidden':
            cols += f'''        column {cname} (
            type: hidden
            layout {{
                sequence: {(i + 1) * 10}
            }}
        )

'''
        else:
            cols += f'''        column {cname} (
            type: {kind}
            heading {{
                heading: {heading}
            }}
            layout {{
                sequence: {(i + 1) * 10}
            }}
{extra}        )

'''
    return f'''    region {rid} (
        name: {name}
        type: classicReport
        source {{
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
{ind(sql, 16)}
                ```{sub}
        }}
        layout {{
            sequence: {seq}
            slot: {slot}{par}
        }}
        appearance {{
            template: @/standard
            templateOptions: #DEFAULT#
        }}
        advanced {{
            htmlDomId: {rid}
        }}
{BADGES if badges else REPORT}
        reportLayout {{
            numberOfRowsType: staticValue
            numberOfRows: 50
        }}
        messages {{
            whenNoDataFound: {nodata}
        }}
{cond}
{cols}    )

'''


REPORT = """        componentAppearance {
            template: @/standard
            templateOptions: [
                #DEFAULT#
                t-Report--stretch
                t-Report--horizontalBorders
            ]
        }
        pagination {
            type: rowRangesXToYOfZWithPagination
        }"""
BADGES = """        componentAppearance {
            template: @/badge-list
            templateOptions: [
                #DEFAULT#
                t-BadgeList--large
                t-BadgeList--flex
            ]
        }
        pagination {
            type: rowRangesXToYNoPagination
        }"""


def wizard_region(seq=5):
    return f'''    region wizard (
        name: Create Request
        type: list
        source {{
            list: @request-wizard
        }}
        layout {{
            sequence: {seq}
            slot: BODY
        }}
        appearance {{
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }}
        componentAppearance {{
            listTemplate: @/wizard-progress
            templateOptions: #DEFAULT#
        }}
        advanced {{
            htmlDomId: wizard
        }}
    )

'''


# ===================================================================== 200


def chart(rid, name, seq, sql, label_col, value_col, chart_type='bar', new_row=True, height=320, nodata='No data.',
          x_title=None, y_title=None, orientation=None, link=None):
    """A JET chart region with one series. chart_type: bar, pie, donut, line, area ... ; link: page opened on click."""
    ctype = '' if chart_type == 'bar' else f'''        chart {{
            type: {chart_type}
        }}
'''
    orient = f'''        chartAppearance {{
            orientation: {orientation}
        }}
''' if orientation else ''
    axes = ''
    if chart_type in ('bar', 'line', 'area', 'lineWithArea'):
        for axis, title in (('x', x_title), ('y', y_title)):
            ttl = f'\n            title: {title}' if title else ''
            axes += f'''
        axis {axis} (
            name: {axis}{ttl}
            majorTicks {{
                show: auto
            }}
            minorTicks {{
                show: false
            }}
        )
'''
    lnk = f'''            link {{
                type: redirectThisApp
                target: {{
                    page: {link}
                }}
            }}
''' if link else ''
    return f'''    region {rid} (
        name: {name}
        type: chart
        layout {{
            sequence: {seq}
            slot: BODY
            startNewRow: {'true' if new_row else 'false'}
        }}
        appearance {{
            template: @/standard
            templateOptions: #DEFAULT#
        }}
        advanced {{
            htmlDomId: {rid}
        }}
{ctype}{orient}        chartLayout {{
            height: {height}
        }}
        legend {{
            show: {'true' if chart_type in ('pie', 'donut') else 'false'}
        }}
        messages {{
            whenNoDataFound: {nodata}
        }}

        series {rid}-series (
            name: {name}
            execution {{
                sequence: 10
            }}
            source {{
                type: sqlQuery
                sqlQuery:
                    ```sql
{ind(sql, 20)}
                    ```
            }}
            columnMapping {{
                label: {label_col}
                value: {value_col}
            }}
{lnk}        )
{axes}
    )

'''
