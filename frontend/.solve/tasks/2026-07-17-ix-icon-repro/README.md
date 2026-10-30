# Minimal repro: ix-icon dynamic [name] binding fails on lazy route navigation

Scaffolds a fresh minimal Angular app at ~/Code/Misc/ix-icon-lazy-route-repro
to reproduce the bug found while investigating the memberships status-icon
issue: a `<ix-icon [name]="someGetter" />` bound dynamically inside a
lazy-loaded route (`loadComponent`) renders Stencil's error-fallback icon
instead of the real one when navigated to via SPA routing, but works fine on
a full page reload. Uses the same package versions as vilocify-frontend:
@angular/core 22, @siemens/ix-icons 3.4.0, @siemens/ix-angular 5.1.0.

## 01-scaffold.sh

Creates the Angular workspace via `ng new` (standalone, routing, skip git)
and installs the @siemens/ix packages.

Verify: run the script, expect it to finish without error and print the
installed package versions.
