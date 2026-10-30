#!/usr/bin/env bash
set -euo pipefail

wl-copy <<'EOF'
| Model | Sort param | In OpenAPI enum |
|---|---|---|
| Component | name, vendor | Yes |
| Membership | userName, userEmail | Yes |
| ComponentRequest | membership | No, dead |
| Subscription | membership | No, dead |
EOF
