"""Fail if common credentials, private keys, or secret file types are found.

This is a lightweight safeguard, not a guarantee that secrets cannot leak.
Review changes before every public push. Run: python3 scripts/check_public_repo.py
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
SKIP = {'.git', '.dart_tool', 'build', '.gradle', '__pycache__', '.pub-cache'}
BLOCKED_NAMES = {'google-services.json', 'googleService-info.plist'.lower(), 'key.properties'}
BLOCKED_ENDINGS = {'.jks', '.keystore', '.p8', '.p12', '.pem', '.key'}
TEXT_EXTENSIONS = {'.dart', '.md', '.yaml', '.yml', '.xml', '.json', '.py', '.sh', '.ps1', '.gradle', '.kts', '.txt', '.properties'}
PATTERNS = {
    'Firebase/Google API key': re.compile(r'AIza[0-9A-Za-z_-]{35}'),
    'GitHub token': re.compile(r'(?:gh[pousr]_[A-Za-z0-9_]{30,}|github_pat_[A-Za-z0-9_]{20,})'),
    'OpenAI-style API token': re.compile(r'sk-(?:proj-)?[A-Za-z0-9_-]{20,}'),
    'AWS access key ID': re.compile(r'AKIA[0-9A-Z]{16}'),
    'Private key PEM': re.compile(r'-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----'),
}

issues = []
count = 0
for path in ROOT.rglob('*'):
    if not path.is_file() or any(part in SKIP for part in path.relative_to(ROOT).parts):
        continue
    count += 1
    relative = path.relative_to(ROOT).as_posix()
    name = path.name.lower()
    if (name == '.env' or name.startswith('.env.') or
            name in BLOCKED_NAMES or path.suffix.lower() in BLOCKED_ENDINGS or
            name.startswith(('service-account', 'serviceaccount', 'firebase-adminsdk')) or
            'serviceaccountkey' in name or name.startswith(('credentials', 'secrets')) and name.endswith('.json')):
        issues.append(f'Blocked file: {relative}')
    if path.suffix.lower() not in TEXT_EXTENSIONS and path.name != '.gitignore':
        continue
    try:
        content = path.read_text(encoding='utf-8')
    except (UnicodeError, OSError):
        continue
    for label, pattern in PATTERNS.items():
        if pattern.search(content):
            issues.append(f'Potential {label} in {relative}')

if issues:
    print('PUBLIC-REPOSITORY SECURITY CHECK FAILED:')
    for issue in issues:
        print(' - ' + issue)
    sys.exit(1)
print(f'Public repository source scan passed ({count} files checked). No matched secret files or token patterns.')
