#!/usr/bin/env python3
"""Reusable page patterns for this application (APEXlang, APEX 26.1).

list_page(): interactive report + Create button + refresh after the drawer closes.
form_page(): drawer form on one table: items, Create / Apply Changes / Delete, processes guarded by
             the generic page-create / page-manage / page-submit authorization schemes.
Pages built from these patterns behave exactly like the hand-written pages 180/181.
"""


def _items_block(items):
    return '\n'.join(items)


def col(name, heading, seq, kind='plainText', dtype='STRING', link=None, pk=False, fmt=None):
    extra = ''
    if link:
        extra += f'''            columnFormatting {{
                htmlExpression:
                    ```html
                    <a href="#{link}#">#{name}#</a>
                    ```
            }}
'''
    if fmt:
        extra += f'''            appearance {{
                formatMask: {fmt}
            }}
'''
    pkl = '\n                primaryKey: true' if pk else ''
    src = f'''            source {{
                dataType: {dtype}{pkl}
            }}
'''
    return f'''        column {name} (
            type: {kind}
            heading {{
                heading: {heading}
            }}
            layout {{
                sequence: {seq}
            }}
{extra}{src}        )
'''


def breadcrumb_region(title):
    return f'''    region breadcrumb (
        name: {title}
        type: breadcrumb
        source {{
            breadcrumb: @breadcrumb
        }}
        layout {{
            sequence: 10
            slot: REGION_POSITION_01
        }}
        appearance {{
            template: @/title-bar
            templateOptions: #DEFAULT#
        }}
        componentAppearance {{
            breadcrumbTemplate: @/breadcrumb
            templateOptions: #DEFAULT#
        }}
    )
'''


def ir_region(rid, name, sql, columns, seq=20, slot='BODY', items_to_submit=None, condition=None):
    sql_ind = '\n'.join(('                ' + l) if l.strip() else '' for l in sql.strip('\n').split('\n'))
    submit = f'\n            pageItemsToSubmit: {items_to_submit}' if items_to_submit else ''
    cond = ''
    if condition:
        cond = f'''        serverSideCondition {{
{condition}
        }}
'''
    return f'''    region {rid} (
        name: {name}
        type: interactiveReport
        source {{
            location: localDatabase
            type: sqlQuery
            sqlQuery:
                ```sql
{sql_ind}
                ```{submit}
        }}
        layout {{
            sequence: {seq}
            slot: {slot}
        }}
        appearance {{
            template: @/interactive-report
            templateOptions: #DEFAULT#
        }}
        advanced {{
            htmlDomId: {rid}
        }}
        componentAppearance {{
            showNullValuesAs: -
        }}
        pagination {{
            type: rowRangesXToY
        }}
        messages {{
            whenNoDataFound: No data found.
        }}
        searchBar {{
            includeSearchBar: true
        }}
        download {{
            formats: [
                csv
                html
            ]
        }}
{cond}
{''.join(c + chr(10) for c in columns)}    )
'''


def refresh_da(region='report', seq=20):
    return f'''    dynamicAction refresh-{region} (
        name: Refresh {region}
        execution {{
            sequence: {seq}
        }}
        when {{
            event: apexafterclosedialog
            selectionType: region
            region: @{region}
        }}

        action refresh-{region}-refresh (
            action: refresh
            affectedElements {{
                selectionType: region
                region: @{region}
            }}
            execution {{
                sequence: 10
                fireOnInit: false
            }}
        )

    )
'''


def list_page(page_id, name, alias, group, help_text, sql, columns, create_label=None, form_page=None,
              extra_regions='', extra=''):
    create = ''
    if create_label and form_page:
        create = f'''    button create (
        buttonName: CREATE
        label: {create_label}
        layout {{
            sequence: 10
            region: @breadcrumb
            slot: CREATE
        }}
        appearance {{
            buttonTemplate: @/text
            hot: true
            templateOptions: #DEFAULT#
        }}
        behavior {{
            action: redirectThisApp
            target: {{
                page: {form_page}
                clearCache: {form_page}
            }}
            warnOnUnsavedChanges: doNotCheck
        }}
        security {{
            authorizationScheme: @page-create
        }}
    )

'''
    return f'''page {page_id} (
    name: {name}
    alias: {alias}
    title: {name}
    pageGroup: @{group}
    appearance {{
        pageTemplate: @/standard
        templateOptions: #DEFAULT#
    }}
    security {{
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

{breadcrumb_region(name)}
{ir_region('report', name, sql, columns)}
{extra_regions}{create}{refresh_da('report')}
{extra})
'''


# ---------------------------------------------------------------- form items
def _lov(lov):
    if lov is None:
        return ''
    kind, value, null_text = lov
    if kind == 'shared':
        body = f'''            type: sharedComponent
            lov: @{value}'''
    else:
        q = '\n'.join('                ' + l for l in value.strip('\n').split('\n'))
        body = f'''            type: sqlQuery
            sqlQuery:
                ```sql
{q}
                ```'''
    nul = ('\n            displayNullValue: true\n            nullDisplayValue: ' + null_text) if null_text else ''
    return f'''        lov {{
{body}{nul}
        }}
'''


def item(p, name, kind, label, seq, column, dtype='varchar2', required=False, lov=None, help_text=None,
         max_len=None, default=None, height=None, parent=None, read_only=None, region='form', pk=False,
         read_only_sql=None):
    """kind: textField, textarea, numberField, selectList, switch, datePicker, hidden, displayOnly."""
    iname = f'P{p}_{name}'
    pkl = '\n            primaryKey: true' if pk else ''
    hgt = f'\n            height: {height}' if height else ''
    if kind == 'hidden':
        return f'''    pageItem {iname} (
        type: hidden
        layout {{
            sequence: {seq}
            region: @{region}
            slot: regionBody
        }}
        source {{
            formRegion: @{region}
            column: {column}
            dataType: {dtype}{pkl}
        }}
        security {{
            sessionStateProtection: checksumRequiredSessionLevel
        }}
    )
'''
    parts = [f'''    pageItem {iname} (
        type: {kind}
        label {{
            label: {label}
            alignment: left
        }}
''']
    parts.append(_lov(lov))
    if parent:
        parts.append(f'''        cascadingLov {{
            parentItems: {parent}
        }}
''')
    parts.append(f'''        layout {{
            sequence: {seq}
            region: @{region}
            slot: regionBody
            alignment: left
        }}
        appearance {{
            template: @/{'required' if required else 'optional'}-floating
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
    if kind == 'displayOnly':
        parts.append('''        settings {
            sendOnPageSubmit: false
        }
''')
    parts.append(f'''        source {{
            formRegion: @{region}
            column: {column}
            dataType: {dtype}{pkl}
        }}
''')
    if default is not None:
        parts.append(f'''        default {{
            type: static
            staticValue: {default}
        }}
''')
    if read_only:
        parts.append(f'''        readOnly {{
            type: expression
            language: plsql
            plsqlExpression:
                ```plsql
                {read_only}
                ```
        }}
''')
    if read_only_sql:
        parts.append(f'''        readOnly {{
            type: rowsReturned
            sqlQuery:
                ```sql
                {read_only_sql}
                ```
        }}
''')
    if help_text:
        parts.append(f'''        help {{
            helpText: {help_text}
        }}
''')
    parts.append('    )\n')
    return ''.join(parts)


def form_page(page_id, name, alias, group, help_text, table, pk_item, items, validations='', extra_processes='',
              width=None, delete=True):
    pk = f'P{page_id}_{pk_item}'
    wdt = f'\n        width: {width}' if width else ''
    dialog = f'''    dialog {{{wdt}
        chained: false
    }}'''
    btn_delete = f'''    button delete (
        buttonName: DELETE
        label: Delete
        layout {{
            sequence: 20
            region: @buttons
            slot: DELETE
        }}
        appearance {{
            buttonTemplate: @/text
            templateOptions: #DEFAULT#
        }}
        behavior {{
            action: submitPage
            executeValidations: false
            warnOnUnsavedChanges: doNotCheck
            databaseAction: delete
            requiresConfirmation: true
        }}
        confirmation {{
            message: &APP_TEXT$DELETE_MSG!RAW.
            style: danger
        }}
        serverSideCondition {{
            type: itemIsNotNull
            item: {pk}
        }}
        security {{
            authorizationScheme: @page-manage
        }}
    )

''' if delete else ''
    return f'''page {page_id} (
    name: {name}
    alias: {alias}
    title: {name}
    pageGroup: @{group}
    appearance {{
        pageMode: modalDialog
        dialogTemplate: @/drawer
        templateOptions: [
            #DEFAULT#
            js-dialog-class-t-Drawer--pullOutEnd
        ]
    }}
{dialog}
    security {{
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

    region form (
        name: {name}
        type: form
        source {{
            location: localDatabase
            type: tableView
            tableName: {table}
        }}
        layout {{
            sequence: 10
            slot: contentBody
        }}
        appearance {{
            template: @/blank-with-attributes
            templateOptions: #DEFAULT#
        }}
        edit {{
            enabled: true
        }}
        advanced {{
            htmlDomId: form
        }}
    )

    region buttons (
        name: Buttons
        type: staticContent
        layout {{
            sequence: 90
            slot: REGION_POSITION_03
        }}
        appearance {{
            template: @/buttons-container
            templateOptions: #DEFAULT#
        }}
    )

{_items_block(items)}
{validations}    button cancel (
        buttonName: CANCEL
        label: Cancel
        layout {{
            sequence: 10
            region: @buttons
            slot: CLOSE
        }}
        appearance {{
            buttonTemplate: @/text
            templateOptions: #DEFAULT#
        }}
        behavior {{
            action: definedByDynamicAction
        }}
    )

    button create (
        buttonName: CREATE
        label: Create
        layout {{
            sequence: 40
            region: @buttons
            slot: CREATE
        }}
        appearance {{
            buttonTemplate: @/text
            hot: true
            templateOptions: #DEFAULT#
        }}
        behavior {{
            action: submitPage
            warnOnUnsavedChanges: doNotCheck
            databaseAction: insert
        }}
        serverSideCondition {{
            type: itemIsNull
            item: {pk}
        }}
        security {{
            authorizationScheme: @page-create
        }}
    )

    button save (
        buttonName: SAVE
        label: Apply Changes
        layout {{
            sequence: 30
            region: @buttons
            slot: NEXT
        }}
        appearance {{
            buttonTemplate: @/text
            hot: true
            templateOptions: #DEFAULT#
        }}
        behavior {{
            action: submitPage
            warnOnUnsavedChanges: doNotCheck
            databaseAction: update
        }}
        serverSideCondition {{
            type: itemIsNotNull
            item: {pk}
        }}
        security {{
            authorizationScheme: @page-manage
        }}
    )

{btn_delete}    dynamicAction cancel-dialog (
        name: Cancel Dialog
        execution {{
            sequence: 10
        }}
        when {{
            event: click
            selectionType: button
            button: @cancel
        }}

        action cancel-dialog-action (
            action: cancelDialog
            execution {{
                sequence: 10
                fireOnInit: false
            }}
        )

    )

    process initialize-form (
        name: Initialize form
        type: formInitialization
        formRegion: @form
        execution {{
            sequence: 10
            point: beforeHeader
        }}
    )

    process process-form (
        name: Process form
        type: formAutoRowProcessing
        formRegion: @form
        execution {{
            sequence: 10
            point: processing
        }}
        successMessage {{
            successMessage: Changes saved.
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: CREATE,SAVE,DELETE
        }}
        security {{
            authorizationScheme: @page-submit
        }}
    )

{extra_processes}    process close-dialog (
        name: Close Dialog
        type: closeDialog
        execution {{
            sequence: 90
            point: processing
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: CREATE,SAVE,DELETE
        }}
    )

)
'''


def fn_validation(name, label, code, item, seq=10, requests='CREATE,SAVE'):
    body = '\n'.join('                ' + l for l in code.strip('\n').split('\n'))
    return f'''    validation {name} (
        name: {label}
        execution {{
            sequence: {seq}
        }}
        validation {{
            type: functionBody
            language: plsql
            plsqlFunctionBody:
                ```plsql
{body}
                ```
        }}
        error {{
            associatedItem: @{item}
        }}
        serverSideCondition {{
            type: requestIsContainedInValue
            value: {requests}
        }}
    )

'''
