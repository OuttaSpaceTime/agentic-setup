#!/usr/bin/env bash
set -euo pipefail

wl-copy <<'EOF'
| Model | Sort key(s) | Joined table | Controller |
|---|---|---|---|
| `Component` (`component.rb:41-44`) | `name`/`component_name`, `vendor` | `Component::Name`, `Component::Vendor` | `components_controller.rb:22` |
| `Membership` (`membership.rb:82-83`) | `user_name`, `user_email` | `User` | `memberships_controller.rb:8` |
| `ComponentRequest` (`component_request.rb:87`) | `membership` | `Membership` | `component_requests_controller.rb:57` |
| `Subscription` (`subscription.rb:92`) | `membership` | `Membership` | `subscriptions_controller.rb:58` |
EOF
