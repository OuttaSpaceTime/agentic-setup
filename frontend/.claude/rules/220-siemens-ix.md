---
paths:
  - "src/**/*.html"
  - "src/**/*.component.ts"
  - "src/**/*.css"
  - "src/icons.ts"
---

# Siemens IX Design System

## Theme Setup

- Theme is **`brand`**, not `classic`: `themeSwitcher.setTheme('brand')` in `ThemeManagerService`
- `styles.css` imports: `siemens-ix-core.css`, `classic-light.css`, `brand-theme.css`
- Tests add `document.body.classList.add('theme-brand-light')` in `beforeAll`
- Light/dark variant toggled via `themeSwitcher.setVariant('light' | 'dark')`

## Elevation

Use IX background tokens to express depth — never invent custom background colors:

| Level | Token | Use for |
|-------|-------|---------|
| Base | `--theme-color-1` | Page background |
| Raised | `--theme-color-2` | Cards, list items, panels |
| Elevated | `--theme-color-3` | Active/selected card, nested panels |
| Floating | `--theme-color-3` + `shadow-4` | Dropdowns, tooltips |

- Borders: use `--theme-color-soft-bdr` (not `--theme-color-4`)
- Active state on list items: `border-color: --theme-color-primary` + `background: --theme-color-3`

<example>

```css
/* Correct — IX elevation tokens */
.list-item { background: var(--theme-color-2); border: 1px solid var(--theme-color-soft-bdr); }
.list-item.active { background: var(--theme-color-3); border-color: var(--theme-color-primary); }
```

</example>

<example type="invalid">

```css
/* Wrong — custom color-mix hack, wrong border token */
.list-item { background: color-mix(in srgb, var(--theme-color-1) 70%, transparent); border: 1px solid var(--theme-color-4); }
```

</example>

## Icons

<critical>

- Icons MUST be registered in `src/icons.ts` before use — unregistered icons render as a broken box
- Icon names are kebab-case of the export name minus the `icon` prefix: `iconBarchart` → `'barchart'` (NOT `'bar-chart'`)
- Always verify the exact name in `src/icons.ts` before using — do not guess from the export name

</critical>

- Registered icons: check `src/icons.ts` for the full list
- Common pitfall: `iconBarChart` does not exist; the correct export is `iconBarchart` → `'barchart'`
- Search icon inside `ix-input`: `<ix-icon name="search" slot="start" size="16" />`
- Prefer reusing sidebar nav icons for matching content types (e.g. component request notifications → `'project-new'`, consumption report → `'barchart'`)

## Components

All IX components are imported from `@siemens/ix-angular/standalone`:

```typescript
import { IxButton, IxIcon, IxInput, IxIconButton, IxEmptyState } from '@siemens/ix-angular/standalone'
```

**`ix-input` value changes** emit `CustomEvent<string>` — always use `$event.detail`:

<example>

```html
<!-- Correct -->
<ix-input (valueChange)="onSearch($event.detail)" />
```

</example>

<example type="invalid">

```html
<!-- Wrong — $event is a CustomEvent, not a string -->
<ix-input (valueChange)="onSearch($event)" />
```

</example>

**Badges / pills**: use `app-card-pill` from `@shared/components/card-pill/card-pill.component` — never write custom pill CSS. Map tint colors to variants:

| Tint | CardPill variant |
|------|-----------------|
| `blue` | `primary` |
| `red` | `alarm` |
| `orange` | `critical` |
| `yellow` | `warning` |
| `gray` | `neutral` |
| `green` | `success` |

**`ix-drawer`**: do not use for mobile overlays — implement a custom CSS overlay instead (see `230-layout-patterns.md`).
