#!/usr/bin/env python3
"""Generate all checked-in data-contract artifacts from the YAML manifest."""
import json, re, sys
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "contracts/data-contract.yaml"
OUT = ROOT / "contracts/generated"

def load():
    with MANIFEST.open() as f: return yaml.safe_load(f)

def fields(data):
    return [(r, f) for r in data["records"] for f in r.get("fields", [])]

def validate(data):
    errors=[]; names=set()
    for r in data["records"]:
        if r["name"] in names: errors.append(f"duplicate record {r['name']}")
        names.add(r["name"])
        if "retention" not in r: errors.append(f"{r['name']} has no retention")
        for f in r.get("fields", []):
            required = ["name","type","required","personal_data","sensitivity","purpose","source","destination","secret","log","deletion"]
            for key in required:
                if key not in f: errors.append(f"{r['name']}.{f.get('name','?')} missing {key}")
            if f.get("secret") and f.get("log"): errors.append(f"secret field is loggable: {r['name']}.{f['name']}")
    declared={x for _,f in fields(data) for x in [f["name"]]}
    for provider in data["providers"]:
        for item in provider["data"]:
            if item not in names and item not in declared: errors.append(f"provider {provider['id']} references undeclared data {item}")
    if errors: raise SystemExit("contract validation failed:\n"+"\n".join(errors))

def json_artifact(data):
    return json.dumps(data, indent=2, sort_keys=True)+"\n"

def ts_type(f):
    return {"string":"string","uuid":"string","enum":"string","timestamp":"string","date":"string","integer":"number","integer_or_null":"number | null","string_or_null":"string | null","boolean":"boolean","constrained_path":"string","opaque_customer_data":"unknown"}.get(f["type"],"unknown")

def generated_types(data):
    out=["// GENERATED FILE. Do not edit; run npm run contracts:generate.",""]
    for r in data["records"]:
        if r["kind"] not in ("request","stored_record","transient_payload"): continue
        out += [f"export interface {''.join(x.title() for x in r['name'].split('_'))} {{"]
        for f in r["fields"]: out.append(f"  {f['name']}{'' if f['required'] else '?'}: {ts_type(f)};")
        out += ["}",""]
    return "\n".join(out)

def generated_validators(data):
    out=["// GENERATED FILE. Do not edit; run npm run contracts:generate.","const ENUMS = "+json.dumps({r['name']:{f['name']:f['values'] for f in r.get('fields',[]) if 'values' in f} for r in data['records']})+";", "", "export function validateRecord(recordName, value) {", "  const record = CONTRACTS[recordName];", "  if (!record) throw new Error(`Unknown contract record: ${recordName}`);", "  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error(`${recordName} must be an object`);", "  const allowed = new Set(record.fields.map((field) => field.name));", "  for (const key of Object.keys(value)) if (!allowed.has(key)) throw new Error(`${recordName}.${key} is not declared`);", "  for (const field of record.fields) {", "    const present = value[field.name] !== undefined && value[field.name] !== null;", "    if (field.required && !present) throw new Error(`${recordName}.${field.name} is required`);", "    if (present && field.type === 'enum' && !ENUMS[recordName]?.[field.name]?.includes(value[field.name])) throw new Error(`${recordName}.${field.name} has an invalid value`);", "    if (present && ['string','uuid','enum','timestamp','constrained_path'].includes(field.type) && typeof value[field.name] !== 'string') throw new Error(`${recordName}.${field.name} must be a string`);", "    if (present && field.type === 'integer' && !Number.isInteger(value[field.name])) throw new Error(`${recordName}.${field.name} must be an integer`);", "  }", "  return value;", "}", "", "export function redactForLog(recordName, value) {", "  const record = CONTRACTS[recordName];", "  if (!record) throw new Error(`Unknown contract record: ${recordName}`);", "  return Object.fromEntries(Object.entries(value || {}).map(([key, value]) => {", "    const field = record.fields.find((candidate) => candidate.name === key);", "    return [key, field?.secret ? '[REDACTED]' : value];", "  }));", "}", "", "const CONTRACTS = "+json.dumps({r['name']:{'fields':r.get('fields',[])} for r in data['records']})+";\n"]
    return "\n".join(out)

def privacy(data):
    cats=sorted({f['personal_data'] for r in data['records'] for f in r.get('fields',[]) if f['personal_data'] != 'none'})
    rows=["<!-- BEGIN GENERATED DATA INVENTORY -->","","### Hosted data inventory","","| Record | Categories | Storage | Retention | Deletion |","|---|---|---|---|---|"]
    for r in data['records']:
        c=sorted({f['personal_data'] for f in r.get('fields',[]) if f['personal_data'] != 'none'}) or ['none']
        rows.append(f"| `{r['name']}` | {', '.join(c)} | `{r['storage']}` | `{r['retention']}` | {r['deletion']} |")
    rows += ["", "Declared personal-data categories: " + ", ".join(f"`{x}`" for x in cats)+".", "", "<!-- END GENERATED DATA INVENTORY -->", ""]
    return "\n".join(rows)

def destinations(data):
    rows=["<!-- BEGIN GENERATED DATA DESTINATIONS -->","","### Subprocessors and data destinations","","| Provider | Services | Role | Contract data |","|---|---|---|---|"]
    for p in data['providers']: rows.append(f"| `{p['id']}` | {', '.join(p['services'])} | {p['role']} | {', '.join('`'+x+'`' for x in p['data'])} |")
    return "\n".join(rows+["","<!-- END GENERATED DATA DESTINATIONS -->",""])

def main():
    data=load(); validate(data); OUT.mkdir(exist_ok=True)
    (OUT/'data-contract.json').write_text(json_artifact(data))
    (OUT/'worker-types.ts').write_text(generated_types(data))
    (OUT/'validators.js').write_text(generated_validators(data))
    (OUT/'validators.d.ts').write_text("export declare function validateRecord(recordName: string, value: unknown): any;\nexport declare function redactForLog(recordName: string, value: Record<string, unknown>): Record<string, unknown>;\n")
    privacy_path=ROOT/'website/src/content/docs/privacy.md'; privacy_path.parent.mkdir(parents=True,exist_ok=True)
    existing=privacy_path.read_text() if privacy_path.exists() else "---\ntitle: Privacy\ndescription: PocketCoder's hosted data flows and privacy inventory.\nhead: []\n---\n\nPocketCoder documents hosted data flows below. Legal prose outside generated sections is maintained manually.\n\n"
    block=privacy(data)+"\n"+destinations(data)
    pattern=re.compile(r"<!-- BEGIN GENERATED DATA INVENTORY -->.*?<!-- END GENERATED DATA INVENTORY -->\n?",re.S)
    existing=pattern.sub('', existing); pattern2=re.compile(r"<!-- BEGIN GENERATED DATA DESTINATIONS -->.*?<!-- END GENERATED DATA DESTINATIONS -->\n?",re.S)
    existing=pattern2.sub('', existing).rstrip()+"\n\n"+block
    privacy_path.write_text(existing)

if __name__ == '__main__': main()
