---
paths:
  - "src/**/*.html"
  - "src/**/*.component.ts"
---

# Accessibility: Keyboard Navigation Only

This project supports **keyboard navigation only**, not full screen-reader accessibility. Do not add ARIA attributes, semantic roles, or other screen-reader enhancements unless explicitly required.

## Supported

- **Keyboard navigation**: Tab, Shift+Tab, Enter, Escape, arrow keys, etc.
- **Visual focus indicators**: CSS `:focus` / `:focus-visible` states
- **Standard HTML elements**: Buttons, links, inputs automatically support keyboard interaction

## Not Supported

- **Screen readers** — do not add `aria-label`, `aria-description`, `role` attributes for a11y purposes
- **ARIA roles** — e.g., `role="list"`, `role="listitem"`, `role="dialog"` are unnecessary
- **ARIA live regions** — e.g., `aria-live="polite"`, `aria-busy`
- **ARIA labels for icons** — icon buttons render without `aria-label`; tooltip text or context provides clarity

## Examples

<example type="invalid">

```html
<!-- ❌ Unnecessary for keyboard navigation -->
<div role="list" aria-label="Items">
  <button role="listitem" aria-label="Item name">
</div>
```

</example>

<example>

```html
<!-- ✅ Keyboard navigation works by default -->
<div class="list">
  <button class="item">Item name</button>
</div>
```

</example>

<example type="invalid">

```html
<!-- ❌ Screen-reader specific, not needed -->
<ix-icon-button icon="refresh" aria-label="Refresh">
```

</example>

<example>

```html
<!-- ✅ Icon button is keyboard accessible, no label needed -->
<ix-icon-button icon="refresh" />
```

</example>

## Rule

Remove all ARIA attributes and semantic roles that serve **only** screen-reader purposes. Keep only:
- Standard HTML form semantics (`<button>`, `<input>`, `<label>`)
- `data-test-id` for testing
- `class` for styling and component logic
- `(click)` / keyboard event handlers for interaction
