---
paths:
  - "app/views/**/*"
  - "app/helpers/**/*"
  - "app/assets/stylesheets/**/*"
---

# Views, Helpers and CSS

## Context

- The portal renders few HTML pages (documentation, changelog, login, mailers). The maintainer
  reviews them with the same structure standards as Ruby code.
- Find the nearest existing view or stylesheet first and follow it.

## Requirements

### Assets

Reference assets through Rails helpers, never hard-coded paths: `stylesheet_link_tag`,
`image_tag`, `favicon_link_tag`, `asset_path`. The helpers respect asset host and prefix
configuration; a literal `/favicon.png` may break in production.

### Structure

- Markup that repeats, such as a section with an `<h2>` and a list, goes into a partial.
- Self-contained page parts go into a partial even when used once (`_breadcrumb`).
- A `link_to` that builds a route with params or anchors goes into a helper with an
  intention-revealing name.
- Formatting a value into HTML (escaping, wrapping in `<code>`, `html_safe`) goes into a helper,
  never into a model or PORO.

<example type="invalid">

```erb
<nav class="changelog__breadcrumb">
  <%= link_to('API documentation', documentation_path(name: @docs_name, anchor: '?route=overview--further-links')) %>
  …
</nav>
```

</example>

<example>

```erb
<%= render('breadcrumb', release: @release) %>

<%# _breadcrumb.html.erb %>
<nav class="changelog__breadcrumb">
  <%= link_to_api_documentation(@docs_name) %>
  …
</nav>
```

</example>

### CSS

- BEM. A modifier class sets the custom property itself; do not derive state from children with
  `:is()` / `:has()`.
- Spacing, container sizes and colors are custom properties on the block root (see the variables
  in `documentation.css`), not literal values repeated across rules.

<example type="invalid">

```css
.changelog__endpoint:has(.changelog__method--get) { --method-color: var(--blue); }
```

</example>

<example>

```css
.changelog__endpoint--get { --method-color: var(--blue); }
```

</example>

### Look at the page before calling a view or CSS change done

Tests don't show layout: tooltips that never appear, text that doesn't wrap and misplaced markers all
passed their tests here. Render the page with headless Chrome in its own profile, then read the
screenshot:

```bash
google-chrome --headless=new --disable-gpu --no-first-run --user-data-dir=<scratchpad>/chrome-profile --hide-scrollbars --window-size=1280,900 --screenshot=<scratchpad>/page.png http://localhost:3000/<path>
```

If you can't render it, say the visual result is unverified and give the user the URL to check.
