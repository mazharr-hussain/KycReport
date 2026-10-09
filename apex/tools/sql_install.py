"""Release 74 (A-02): one SQL install script per application, for ADMIN to run in SQL Developer Web (Database
Actions > SQL > Run Script) instead of the App Builder import screen.

Each script sets the workspace (XXCUS), the application ID, the parsing schema (COMMON: XXFUSION, KYC: XXCUS - no
manual parsing-schema switch any more) and installs the supporting objects (install scripts on a new database,
upgrade scripts on an existing one), then installs the application.

Input: the classic SQL exports (SQLcl `apex export -applicationid N -expSupportingObjects Y`) of the applications built
from this release's APEXlang source. Output: apex/<zip name>-SQL-Install_<release>.sql.
Usage: python3 apex/tools/sql_install.py --release 74 --common f135.sql --kyc f134.sql
"""
import argparse, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APPS = {'COMMON': (135, 'XXFUSION', 'COMMON', 'COMMON-Application-APEXlang'),
        'KYC':    (134, 'XXCUS',    'KYC',    'KYC-Compliance-Platform-APEXlang')}
ORDER = {'COMMON': 'Run this script first (KYC uses the objects it installs).',
         'KYC': 'Run the COMMON script of the same release first.'}


def write(app, export, release):
    app_id, schema, alias, name = APPS[app]
    target = os.path.join(ROOT, f'{name.replace("-APEXlang", "")}-SQL-Install_{release}.sql')
    head = f"""-- {app} application, release {release}: install / upgrade from SQL Developer Web.
-- Run as ADMIN: Database Actions > SQL > paste or open this file > Run Script (F5).
-- {ORDER[app]}
-- Workspace XXCUS, application {app_id}, parsing schema {schema}; supporting objects run automatically
-- (install scripts on a new database, upgrade scripts when the application's objects already exist).
whenever sqlerror exit sql.sqlcode rollback
begin
    apex_application_install.set_workspace('XXCUS');
    apex_application_install.set_application_id({app_id});
    apex_application_install.set_schema('{schema}');
    apex_application_install.set_application_alias('{alias}');
    apex_application_install.set_auto_install_sup_obj(p_auto_install_sup_obj => true);
end;
/
"""
    with open(target, 'w') as out:
        out.write(head)
        with open(export) as src:
            for line in src:
                out.write(line)
    print('wrote', target)


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--release', type=int, required=True)
    ap.add_argument('--common')
    ap.add_argument('--kyc')
    a = ap.parse_args()
    if a.common:
        write('COMMON', a.common, a.release)
    if a.kyc:
        write('KYC', a.kyc, a.release)
