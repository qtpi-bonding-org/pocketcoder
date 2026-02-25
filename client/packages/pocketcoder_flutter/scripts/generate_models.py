import json
import os
import re

# Configuration
SCHEMA_PATH = 'assets/pb_schema.json'
# We'll put all generated models in a single directory as requested
OUTPUT_DIR = 'lib/domain/models'

# Collections to skip (system or specialized)
SKIP_COLLECTIONS = ['_mfas', '_otps', '_externalAuths', '_authOrigins', '_superusers', 'users']

# Mapping for specific collection names to class names
CLASS_NAME_OVERRIDES = {}

def snake_to_camel(snake_str):
    if not snake_str: return ""
    components = snake_str.split('_')
    return components[0] + ''.join(x.title() for x in components[1:])

def snake_to_pascal(snake_str):
    if not snake_str: return ""
    clean_str = snake_str.lstrip('_')
    components = clean_str.split('_')
    return ''.join(x.title() for x in components)

def singularize(name):
    if name.endswith('s') and not name.endswith('ss'):
        return name[:-1]
    return name

def get_dart_type(field):
    pb_type = field.get('type')
    if pb_type in ['text', 'email', 'url', 'file', 'relation']:
        return 'String'
    if pb_type == 'number':
        return 'double'
    if pb_type == 'bool':
        return 'bool'
    if pb_type in ['date', 'autodate']:
        return 'DateTime'
    if pb_type == 'json':
        return 'dynamic'
    return 'dynamic'

def generate_model(collection):
    coll_name = collection['name']
    if coll_name in SKIP_COLLECTIONS:
        return

    # Determine Class Name: Check overrides first, else rank-and-file drop-the-s
    class_name = CLASS_NAME_OVERRIDES.get(coll_name)
    if not class_name:
        class_name = snake_to_pascal(singularize(coll_name))

    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)

    # Determine File Name: use override basis if exists
    if coll_name in CLASS_NAME_OVERRIDES:
        # ChatMessage -> chat_message.dart
        file_name = re.sub(r'(?<!^)(?=[A-Z])', '_', class_name).lower() + '.dart'
    else:
        file_name = f"{singularize(coll_name)}.dart"
    
    output_path = os.path.join(OUTPUT_DIR, file_name)
    
    fields = []
    enums = []
    
    for field in collection['fields']:
        f_name = field['name']
        f_type = field['type']
        dart_name = snake_to_camel(f_name)
        dart_type = get_dart_type(field)
        
        is_required = field.get('required', False) or f_name == 'id'
        
        # Determine if we should treat it as enum
        if f_type == 'select':
            enum_name = class_name + snake_to_pascal(f_name)
            dart_type = enum_name
            enum_values = field.get('values', [])
            enums.append({
                'name': enum_name,
                'values': enum_values
            })

        fields.append({
            'pb_name': f_name,
            'dart_name': dart_name,
            'dart_type': dart_type,
            'is_required': is_required
        })

    # Generate Dart Code
    lines = [
        "import 'package:freezed_annotation/freezed_annotation.dart';",
        "import 'package:pocketbase/pocketbase.dart';",
        "",
        f"part '{file_name.replace('.dart', '.freezed.dart')}';",
        f"part '{file_name.replace('.dart', '.g.dart')}';",
        "",
        "@freezed",
        f"class {class_name} with _${class_name} {{",
        "  const factory " + class_name + "({",
    ]

    for f in fields:
        line = "    "
        if f['is_required']:
            line += "required "

        suffix = ''
        if not f['is_required']:
            if f['dart_type'] != 'dynamic':
                suffix = '?'
        
        line += f"{f['dart_type']}{suffix} {f['dart_name']},"
        lines.append(line)

    lines.extend([
        "  }) = _" + class_name + ";",
        "",
        f"  factory {class_name}.fromRecord(RecordModel record) =>",
        f"      {class_name}.fromJson(record.toJson());",
        "",
        f"  factory {class_name}.fromJson(Map<String, dynamic> json) =>",
        f"      _${class_name}FromJson(json);",
        "}",
        ""
    ])

    for en in enums:
        lines.append(f"enum {en['name']} {{")
        seen_vals = set()
        for val in en['values']:
            # Handle empty values and sanitization
            safe_val = val.replace('-', '_').replace(' ', '_').lower()
            if not safe_val: safe_val = "none"
            if safe_val in ['enum', 'class', 'in', 'out', 'default', 'new', 'switch', 'case']: 
                safe_val = f"v_{safe_val}"
            
            orig_safe_val = safe_val
            counter = 1
            while safe_val in seen_vals:
                safe_val = f"{orig_safe_val}_{counter}"
                counter += 1
            seen_vals.add(safe_val)

            lines.append(f"  @JsonValue('{val}')")
            lines.append(f"  {safe_val},")
        
        if 'unknown' not in seen_vals:
            lines.append("  @JsonValue('__unknown__')")
            lines.append("  unknown,")
            
        lines.append("}")
        lines.append("")

    with open(output_path, 'w') as f:
        f.write('\n'.join(lines))
    
    print(f"Generated {output_path}")

def main():
    if not os.path.exists(SCHEMA_PATH):
        print(f"Schema not found at {SCHEMA_PATH}")
        return
        
    with open(SCHEMA_PATH, 'r') as f:
        data = json.load(f)
        
    for item in data['items']:
        generate_model(item)

if __name__ == '__main__':
    main()
