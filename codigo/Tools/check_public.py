"""Local publication checks; no network, no secret upload and no dependencies."""
from pathlib import Path
import json,re,sys
root=Path(__file__).resolve().parents[2]
include=list(root.glob('*.md'))+list(root.glob('*.command'))+list((root/'docs').rglob('*'))+list((root/'codigo').rglob('*'))
patterns={
 'private key':r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
 'AWS credential':r'\bAKIA[A-Z0-9]{16}\b',
 'GitHub credential':r'\b(?:ghp_|gho_|github_pat_)[A-Za-z0-9_]{30,}\b',
 'service credential':r'\b(?:sk_live_|sk-ant-|xoxb-|xoxp-)[A-Za-z0-9_-]{20,}\b',
 'Google API credential':r'\bAIza[A-Za-z0-9_-]{30,}\b|\bAQ\.[A-Za-z0-9_-]{35,}\b',
 'personal absolute path':r'/Users/[^/\s]+/',
 'email address':r'\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b',
}
issues=[]
for path in include:
 if not path.is_file() or path.suffix in ['.icns','.png']:continue
 if path.name==Path(__file__).name:continue # This file contains the detector expressions.
 text=path.read_text(errors='replace')
 for label,pattern in patterns.items():
  matches=re.findall(pattern,text,re.I)
  if label=='email address':
   matches=[value for value in matches if not value.lower().endswith(('@example.com','@example.org','@example.net'))]
  if matches:issues.append((str(path.relative_to(root)),label))
manifest=json.loads((root/'codigo/Extension/manifest.json').read_text())
if manifest.get('host_permissions'):issues.append(('manifest.json','required host access'))
if manifest.get('content_scripts'):issues.append(('manifest.json','unexpected page scripts'))
if set(manifest['permissions'])!={'nativeMessaging','declarativeNetRequestWithHostAccess','storage','alarms'}:issues.append(('manifest.json','unexpected permissions'))
if not (root/'.gitignore').is_file():issues.append(('.gitignore','missing'))
for path,label in issues:print(f'{path}: {label}')
if issues:raise SystemExit(1)
print('Publication checks passed: no detected private credentials/personal paths/emails; optional site permissions and expected extension capabilities.')
