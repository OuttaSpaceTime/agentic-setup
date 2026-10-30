#!/usr/bin/env bash
set -euo pipefail

wl-copy <<'EOF'
| Model | Sort param | Joined table | Controller | In OpenAPI enum? |
|---|---|---|---|---|
| `Component` (`component.rb:41-44`) | `name`/`component_name`, `vendor` | `Component::Name`, `Component::Vendor` | `components_controller.rb:22` | Yes |
| `Membership` (`membership.rb:82-83`) | `user_name`, `user_email` | `User` | `memberships_controller.rb:8` | Yes |
| `ComponentRequest` (`component_request.rb:87`) | `membership` | `Membership` | `component_requests_controller.rb:57` | No — dead |
| `Subscription` (`subscription.rb:92`) | `membership` | `Membership` | `subscriptions_controller.rb:58` | No — dead |
EOF
