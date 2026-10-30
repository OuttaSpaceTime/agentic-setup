# Instrumented verification of the ix-icon lazy-route bug

Builds a fresh Angular app at ~/Code/Misc/ix-icon-verify with:
- ix-icon prototype instrumented (componentWillLoad + name/lazyLoading setters
  logged with timestamps and current values) so we can see the real ordering.
- Several lazy routes, each a VARIANT of the icon usage, to test each claim:
  - plain     : <ix-icon [name]="statusIcon">           (always-truthy getter, no setTimeout)
  - delayed   : name undefined -> 'success' after 15ms   (the earlier repro pattern)
  - lazyprop  : <ix-icon [name] [lazyLoading]="true">
  - lazyattr  : <ix-icon [name] lazy-loading>            (static attribute)
  - guardif   : @if (statusIcon) { <ix-icon [name]> }
  - svgdata   : [name]="iconSuccess data URI"
- A Playwright script (system Chrome, headless) navigates A -> each variant via
  SPA routerLink, then reports for each: console warnings seen + whether the
  shadow DOM ended up on the checkmark or the error-fallback X.

Same versions as vilocify: @angular/core 22, ix-icons 3.4.0, ix-angular 5.1.0,
zone.js enabled (matches vilocify).

## 01-scaffold.sh
Creates the workspace, installs ix packages + playwright, enables zone.js.
Verify: finishes without error, prints installed versions.
