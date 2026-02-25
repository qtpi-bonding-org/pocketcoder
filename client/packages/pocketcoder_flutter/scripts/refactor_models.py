import os
import re

ROOT_DIR = 'lib'

MODEL_FILES = [
    'ai_agent', 'ai_model', 'ai_prompt', 'chat', 'device', 'healthcheck',
    'mcp_server', 'message', 'permission', 'proposal', 'sop', 'ssh_key',
    'subagent', 'whitelist_action', 'whitelist_target'
]

CORE_INFRA = [
    'base_dao', 'collections', 'api_client', 'api_endpoints', 'logger', 'auth_store'
]

# Bundle expansion replacement (any import with ai_models.dart)
BUNDLE_EXPANSION = "\n".join([f"import 'package:pocketcoder_flutter/domain/models/{f}.dart';" for f in ['ai_agent', 'ai_prompt', 'ai_model']])

def process_file(file_path):
    with open(file_path, 'r') as f:
        content = f.read()
    
    new_content = content
    
    # Simple replacements
    repls = {
        r'\bChatMessageRole\b': 'MessageRole',
        r'\bChatMessageEngineMessageStatus\b': 'MessageEngineMessageStatus',
        r'\bChatMessageUserMessageStatus\b': 'MessageUserMessageStatus',
        r'\bChatMessageErrorDomain\b': 'MessageErrorDomain',
        r'\bChatMessage\b': 'Message',
        r'\bPermissionRequest\b': 'Permission',
        r'\bPermissionRequestStatus\b': 'PermissionStatus',
        r'package:pocketcoder_flutter/core/widgets/': 'package:pocketcoder_flutter/presentation/core/widgets/',
        r'package:pocketcoder_flutter/try_operation\.dart': 'package:pocketcoder_flutter/core/try_operation.dart',
    }
    
    for pattern, replacement in repls.items():
        new_content = re.sub(pattern, replacement, new_content)
    
    # Path normalization
    lines = new_content.split('\n')
    for i, line in enumerate(lines):
        if "import '" in line and ".dart" in line:
            # 1. Expand bundled ai_models
            if "ai_models.dart" in line:
                lines[i] = BUNDLE_EXPANSION
                continue
            
            # 2. Catch ANY import of a model file and redirect to models/
            m_model = re.search(r"import '([^']+/)?(" + "|".join(MODEL_FILES) + r")\.dart'", line)
            if m_model:
                lines[i] = f"import 'package:pocketcoder_flutter/domain/models/{m_model.group(2)}.dart';"
                continue
            
            # 3. Normalize relative imports to package:
            if "package:" not in line:
                m = re.search(r"import '(\.\./)+((domain|infrastructure|application|core|design_system|presentation|app)/[^']+)\.dart'", line)
                if m:
                    path = m.group(2)
                    # Correction for core/ mistakes
                    if path.startswith("core/"):
                        filename = path.split('/')[-1]
                        if filename in CORE_INFRA:
                            path = "infrastructure/" + path
                    lines[i] = f"import 'package:pocketcoder_flutter/{path}.dart';"
        
        # 4. Correct package: core paths
        if "package:pocketcoder_flutter/core/" in lines[i]:
            filename_part = lines[i].split('/')[-1]
            filename = filename_part.split('.')[0]
            if filename in CORE_INFRA:
                lines[i] = lines[i].replace("core/", "infrastructure/core/")
    
    new_content = '\n'.join(lines)
    
    if new_content != content:
        with open(file_path, 'w') as f:
            f.write(new_content)
        print(f"Updated {file_path}")

def main():
    for start_dir in ['lib', 'test']:
        if not os.path.exists(start_dir):
            continue
        for root, dirs, files in os.walk(start_dir):
            for file in files:
                if file.endswith('.dart') and not (file.endswith('.freezed.dart') or file.endswith('.g.dart')):
                    process_file(os.path.join(root, file))

if __name__ == '__main__':
    main()
