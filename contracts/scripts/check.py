#!/usr/bin/env python3
import argparse, json, os, re, subprocess, sys
from pathlib import Path
import yaml

ROOT=Path(__file__).resolve().parents[2]
MANIFEST=ROOT/'contracts/data-contract.yaml'

def fail(errors):
    if errors:
        print('contract checks failed:\n'+'\n'.join(f' - {e}' for e in errors), file=sys.stderr)
        raise SystemExit(1)

def main():
    args=argparse.ArgumentParser(); args.add_argument('--privacy-only',action='store_true'); opts=args.parse_args()
    data=yaml.safe_load(MANIFEST.read_text()); records={r['name']:r for r in data['records']}
    errors=[]
    if not opts.privacy_only:
        subprocess.run([sys.executable,str(ROOT/'contracts/scripts/generate.py')],check=True)
        external_root=Path(os.environ.get('POCKETCODER_PRO_ROOT', str(ROOT.parents[2]/'pocketcoder-pro')))
        sql_path=external_root/'workers/push-relay/migrations/0001_init.sql'
        sql=sql_path.read_text() if sql_path.exists() else ''
        if not sql:
            print('note: proprietary push-relay SQL not present; public manifest boundary retained')
        sql_tables=[(sql,'relay_bindings','relay_binding',['secret_hash','user_id','bound_at']),
                    (sql,'push_quota','push_quota',['user_id','day','count'])] if sql else []
        sql_tables.append(((ROOT/'workers/image-relay/migrations/0001_init.sql').read_text(),'image_relay_revocations','image_relay_revocation',['jti','revoked_at']))
        for table_sql, table, record, cols in sql_tables:
            m=re.search(r'create\s+table\s+if\s+not\s+exists\s+'+table+r'\s*\((.*?)\);',table_sql,re.I|re.S)
            if not m:
                errors.append(f'SQL table missing: {table}')
                continue
            manifest_cols={f['name'] for f in records[record]['fields']}
            if manifest_cols != set(cols): errors.append(f'{record} manifest columns {sorted(manifest_cols)} != SQL columns {cols}')
            for col in cols:
                if not re.search(r'\b'+re.escape(col)+r'\b',m.group(1),re.I): errors.append(f'SQL column missing: {table}.{col}')
        source_path=external_root/'workers/push-relay/src/index.js'
        source=source_path.read_text() if source_path.exists() else ''
        if source:
            for key in ['token','user_id','service','title','message','type','chat']:
                if not re.search(r'\b'+key+r'\b',source): errors.append(f'push source key absent from implementation: {key}')
        oauth=(ROOT/'workers/oauth-relay/src/index.js').read_text()
        for key in ['provider','code_challenge','code','state','exchange_code','code_verifier','refresh_token']:
            if not re.search(r'\b'+key+r'\b',oauth): errors.append(f'oauth source key absent from implementation: {key}')
        for record in data['records']:
            for field in record.get('fields',[]):
                if field['secret'] and field['log']: errors.append(f'secret field may be logged: {record["name"]}.{field["name"]}')
        # Explicitly reject common direct logging of secret-bearing request keys.
        for file_name, text in [('push-relay/src/index.js',source),('oauth-relay/src/index.js',oauth)]:
            for line_no,line in enumerate(text.splitlines(),1):
                if re.search(r'console\.(log|error|warn).*\b(refresh_token|access_token|code_verifier|authorization_code|client_secret|private_key|reqBody)\b',line): errors.append(f'suspicious secret logging at {file_name}:{line_no}')
        privacy=(ROOT/'website/src/content/docs/privacy.md').read_text()
        for marker in ['BEGIN GENERATED DATA INVENTORY','END GENERATED DATA INVENTORY','BEGIN GENERATED DATA DESTINATIONS','END GENERATED DATA DESTINATIONS']:
            if f'<!-- {marker} -->' not in privacy: errors.append(f'privacy marker missing: {marker}')
    else:
        privacy=(ROOT/'website/src/content/docs/privacy.md').read_text()
    inventory=privacy.split('<!-- BEGIN GENERATED DATA INVENTORY -->',1)[-1].split('<!-- END GENERATED DATA INVENTORY -->',1)[0]
    for category in data['categories']:
        if category not in inventory and category != 'customer_defined': errors.append(f'privacy inventory omits category: {category}')
    fail(errors)
    print('contract checks passed')

if __name__=='__main__': main()
