# DataPilot — Component Specifications

> Every component from the recon map, fully specified: variants, sizes, states,
> tokens, accessibility, and which screens use it. Build these in isolation
> (shadcn/ui + Radix primitives) before any screen.

Base library: **shadcn/ui** (built on Radix UI primitives)
Icons: **Lucide React** (MIT, consistent 24×24 stroke set)

---

## 1. Button

```
variants    primary, secondary, ghost, danger, icon-only
sizes       sm (h-8 px-3 text-sm), md (h-9 px-4 text-base), lg (h-11 px-6 text-md)
states      default, hover (+accent-hover bg), active (scale 0.98), focus-visible
            (3px ring accent/35), disabled (opacity 50, pointer-events-none),
            loading (spinner replaces icon, label stays for screen readers)
tokens      primary: bg accent, text on-accent, radius md
            secondary: bg bg, text text, border border, hover bg surface
            ghost: bg transparent, text text-muted, hover bg surface
            danger: bg danger, text on-danger, hover bg danger-hover
a11y        <button> element. aria-disabled when disabled. aria-busy + spinner
            when loading — label text kept in DOM for screen readers.
            Visible focus ring on :focus-visible only (not :focus).
used on     all screens
```

---

## 2. Icon Button

```
variants    default, ghost, danger
sizes       sm (h-8 w-8), md (h-9 w-9), lg (h-11 w-11)
states      same as Button
tokens      ghost: bg transparent, text text-muted, hover bg surface, radius md
a11y        <button> with aria-label (required). Tooltip on hover via Radix Tooltip.
used on     S03 (notification bell), S11 (cancel), S16 (delete), S19 (remove object)
```

---

## 3. Navigation Sidebar

```
variants    expanded (240px), collapsed (64px icon-only)
sections    Dashboard, Import, Migration, Backup, Flows, Settings (with sub-items)
states      expanded (labels visible), collapsed (icons only + tooltip),
            active item (bg sidebar-active, text text-inverse, radius md),
            hover item (bg sidebar-hover), section expanded/collapsed
tokens      bg sidebar-bg, text sidebar-text, active sidebar-active,
            border-right 1px border, shadow none
layout      fixed left, full height, z-sticky. Collapse toggle at bottom.
a11y        <nav aria-label="Main"> with <ul> + <li>. aria-current="page" on active.
            Collapsed: aria-label on each icon, Radix Tooltip.
            Keyboard: Tab through items, Enter/Space to select.
used on     S03–S32 (all authenticated screens)
```

---

## 4. Header Bar

```
variants    standard (with org selector + user menu)
states      default, search active, notifications present (badge dot)
tokens      bg bg, border-bottom 1px border, h-14, shadow xs
layout      fixed top, left-offset by sidebar width, z-sticky
elements    - Breadcrumb (text-muted, separator /)
            - Org selector dropdown (right side)
            - Notification bell (icon button + red dot badge)
            - User avatar + dropdown menu
a11y        Skip-to-content link as first focusable. Breadcrumb as <nav aria-label="Breadcrumb">.
used on     S03–S32
```

---

## 5. Org Selector Dropdown

```
variants    single-select (header), context selector (wizard)
states      default (shows current org label + badge), open (dropdown with search),
            loading orgs, error (red border + message), empty (no orgs connected)
tokens      bg bg, border border-input, radius md, shadow md (open),
            badge: production=accent, sandbox=warning, developer=info
a11y        Radix Select. aria-label "Select Salesforce org". Keyboard: Arrow keys,
            Enter to select, Escape to close. Type-ahead search.
used on     S03, S04, S17, S18, S20
```

---

## 6. File Upload Dropzone

```
variants    default (full-width), compact (inline in wizard step)
states      idle (dashed border, text-muted "Drag CSV or Excel here"),
            dragging-over (border accent, bg accent-light, scale 1.01),
            file-selected (file name + size + remove button),
            uploading (progress bar inside zone),
            error (border danger, error message below)
tokens      border 2px dashed border-input, radius lg, bg bg-raised, min-h 160px
            icon: Lucide Upload, 48px, text-subtle
a11y        <input type="file"> visually hidden, label is the entire dropzone.
            accept=".csv,.xlsx,.xls". Keyboard: Tab to focus, Space/Enter to open picker.
            Drag events have aria-live announcement.
used on     S06
```

---

## 7. Object Picker

```
variants    single-select, multi-select (with chips)
states      default (placeholder "Search objects..."), searching (filtered list),
            selected (chip with object label + API name), multi-select (chip stack),
            loading (skeleton items), no results, error
tokens      bg bg, border border-input, radius md, shadow md (open),
            chip: bg surface, text text, radius pill, text-xs, x-button ghost
            group headers: text-xs text-subtle uppercase tracking-wide
a11y        Combobox pattern (Radix Combobox). aria-label "Select Salesforce object".
            Grouped: Standard Objects, Custom Objects. Keyboard: type to filter,
            arrow keys to navigate, Enter to select, Backspace to remove chip.
used on     S07, S19, S24
```

---

## 8. Field Mapping Table

```
variants    standard (import), migration (auto-mapped with Magic ID indicator)
columns     source column | → arrow | target SF field | lookup config | formula | actions
states      auto-mapped (green check icon), manually mapped (blue dot),
            unmapped (yellow warning triangle + text "Required"), formula applied
            (fx icon in purple), lookup configured (link icon in accent)
tokens      bg bg, border-collapse, row hover bg bg-raised, row-h 44px,
            header: bg surface, text-xs text-subtle font-500 uppercase
            arrow: Lucide ArrowRight, text-subtle
a11y        <table> with <thead>. Each cell editable via Radix Select or input.
            Keyboard: Tab between cells, arrow keys within dropdowns.
            aria-invalid on unmapped required fields. Screen reader: "AccountId
            mapped to Account Name, lookup configured".
used on     S08, S18
```

---

## 9. Formula Editor

```
variants    inline (inside mapping table cell), expanded (slide-out panel)
states      empty (placeholder "e.g. IF(ISNULL($Name),'Unknown',$Name)"),
            editing (syntax highlighting), syntax error (red underline + message),
            preview result (shows transformed sample value)
tokens      bg bg, border border-input, radius md, font mono, text-sm
            functions: highlighted in accent, strings in success, errors in danger
a11y        <textarea> with aria-label "Formula expression". Autocomplete popup
            for function names (IF, ISNULL, CONTAINS, CONCAT, SPLIT, REPLACE).
            Error messages in aria-live region.
used on     S08, S09
```

---

## 10. Filter / Rule Builder

```
variants    visual (row-based rules), SQL editor (database sources)
states      no filters (empty + "Add filter" button), one+ filters (rule rows),
            filter active (count badge), syntax error (SQL mode, red underline)
rule row    [field dropdown] [operator dropdown] [value input] [remove button]
            operators: equals, not equals, contains, starts with, is empty, in list
tokens      bg bg-raised, border border, radius lg, row gap space-2
            SQL mode: font mono, bg surface, min-h 120px
a11y        Visual: each row is a fieldset with legend "Filter rule {n}".
            SQL: <textarea> with aria-label "SQL WHERE clause".
            Add/remove buttons with aria-label.
used on     S09, S17
```

---

## 11. Data Preview Table

```
variants    standard (paginated), compact (sample run results)
states      loading (skeleton rows), populated (data with headers),
            empty (illustration + "No data to preview"), validation errors
            (cells with red bg danger-light + tooltip showing error)
tokens      bg bg, border border, radius lg, shadow xs
            header: bg surface, text-xs text-subtle font-500, sticky top
            row-h 40px, row hover bg bg-raised, stripe odd bg-raised
            pagination: text-sm, page buttons ghost variant
a11y        <table> with sticky <thead>. aria-sort on sortable columns.
            Validation errors: aria-describedby pointing to error tooltip.
            Pagination: <nav aria-label="Pagination">.
used on     S10, S20, S26
```

---

## 12. Progress Bar

```
variants    determinate (% fill), indeterminate (animated shimmer)
sizes       sm (h-1.5), md (h-2), lg (h-3)
states      running (accent fill, animated), paused (surface-alt fill),
            completed (success fill), failed (danger fill)
tokens      track: bg surface, radius pill
            fill: bg accent (running), bg success (done), bg danger (failed)
            transition: width motion-base ease
a11y        <progress> element or <div role="progressbar" aria-valuenow aria-valuemin
            aria-valuemax aria-label="Import progress">. Percentage announced by
            screen reader at 25% intervals.
used on     S11, S06 (upload)
```

---

## 13. Job Execution Panel

```
layout      full-width card below header
elements    - Progress bar (lg variant)
            - Stats row: records processed | success | errors | elapsed time
            - Current object label (e.g. "Processing: Contact")
            - Live log stream (font mono, bg sidebar-bg, text sidebar-text, max-h 300px, auto-scroll)
            - Action buttons: Cancel (danger), View Details (secondary)
states      running, paused, completed (green banner), failed (red banner), cancelled
tokens      bg bg, border border, radius lg, shadow sm, padding space-6
a11y        aria-live="polite" on stats counters (update every 5s max).
            Log stream: role="log" aria-label="Job execution log".
            Cancel button: confirm dialog before action.
used on     S11
```

---

## 14. Job Results Summary Card

```
variants    success (all records), partial (some errors), failure (all errors)
elements    - Status icon (CheckCircle/AlertTriangle/XCircle)
            - Counts: total, success (green), errors (red)
            - Duration
            - Action buttons: Download CSV, Retry Failed, Rollback, View Errors
states      all success (success-light bg, success border-left 4px),
            partial (warning-light bg, warning border-left),
            all failed (danger-light bg, danger border-left)
tokens      bg varies by status, radius lg, shadow sm, padding space-6
a11y        role="status" on the card. Icon has aria-hidden, text conveys status.
            Action buttons clearly labeled.
used on     S12
```

---

## 15. Error Table

```
columns     row # | object | field | error code | error message | actions
states      errors present (paginated), no errors (success illustration),
            retrying (loading spinner on selected rows)
tokens      same as Data Preview Table but row bg danger-light on error rows
            error code: font mono, text-xs, bg surface, radius sm, px-2
a11y        Same as Data Preview Table. Error code as <code> element.
            Retry button per row + bulk retry for selected.
used on     S14
```

---

## 16. Rollback Confirmation Modal

```
layout      centered modal (modal-sm width), overlay bg rgba(0,0,0,0.5)
elements    - Warning icon (Lucide AlertTriangle, text warning)
            - Title: "Rollback {n} records?"
            - Description: scope explanation
            - Cancel (secondary) + Confirm Rollback (danger) buttons
states      confirmation (default), in-progress (progress bar replaces buttons),
            complete (success message + close), failed (error message + retry)
tokens      bg bg, radius xl, shadow pop, padding space-6
a11y        Radix AlertDialog. Focus trapped. aria-labelledby on title,
            aria-describedby on description. Escape to cancel.
            Auto-focus on Cancel (safe action first).
used on     S15
```

---

## 17. Schedule Frequency Picker

```
variants    radio group (simple), custom cron editor
options     Every 15 min, Hourly, Daily, Weekly, Custom (shows cron input)
states      no schedule (empty + "Add schedule" button), schedule set (shows next
            run time), schedule paused (muted, "Paused" badge)
tokens      radio: accent ring, label text, description text-muted
            cron input: font mono, bg surface, radius md
            next-run preview: text-sm text-muted, Lucide Clock icon
a11y        <fieldset> + <legend>. Radio buttons via Radix RadioGroup.
            Cron input: aria-label "Cron expression", with help tooltip.
            Timezone: separate <select> with aria-label "Timezone".
used on     S22
```

---

## 18. Backup Policy Card

```
layout      horizontal card in a list
elements    - Policy name + status badge (Active/Paused)
            - Objects list (chips, max 5 visible + "+N more")
            - Retention: "{N} days" label
            - Compression: "gzip" badge (if enabled)
            - Last run timestamp + status (success/failed)
            - Actions: Edit, Pause/Resume, Delete
states      active (default), paused (muted opacity), nearing storage limit
            (warning badge), last run failed (danger badge)
tokens      bg bg, border border, radius lg, shadow xs, padding space-4
a11y        <article> with aria-label "Backup policy: {name}".
            Status badge as <span role="status">. Action buttons labeled.
used on     S23, S24
```

---

## 19. Snapshot Timeline

```
variants    list view (default), calendar heatmap (future)
elements    - Date header (grouped by month)
            - Snapshot row: date, type badge (Full/Incremental), record counts,
              delta indicators (↑inserts ↓deletes ~updates), storage size, actions
states      populated (list of snapshots), empty ("No backups yet"), single detail
            (expanded view with per-object breakdown)
tokens      bg bg, border border, radius lg
            delta: inserts text success, updates text accent, deletes text danger
            type badge: full=accent-light, incremental=surface
a11y        <ol> with <li> per snapshot. Delta counts have aria-label
            "5 records inserted, 12 updated, 0 deleted".
used on     S25
```

---

## 20. Record Comparison Viewer

```
layout      side-by-side two-column table (Before | After)
elements    - Object + record ID header
            - Field rows: field name | before value | after value
            - Changed fields highlighted, unchanged dimmed
states      loaded (diff visible), no changes (message), loading (skeleton)
tokens      changed row: bg accent-light, before=text-muted strikethrough,
            after=text font-500
            unchanged: text-subtle, bg bg
a11y        <table> with <caption> "Field comparison for {RecordId}".
            Changed cells have aria-label "Changed from {old} to {new}".
used on     S26
```

---

## 21. Connector Config Form

```
variants    per connector type (S3, SFTP, PostgreSQL, Google, SharePoint, etc.)
elements    - Connector type icon + label header
            - Type-specific credential fields (inputs, password inputs, textareas)
            - Test Connection button (secondary, with loading state)
            - Test result: success (green check + "Connected") or failure (red x + error)
            - Save / Cancel buttons
states      new (empty form), configured (filled, test not run), test-pass
            (green border glow), test-fail (red border + error), saving (loading)
tokens      bg bg, border border, radius lg, padding space-6
            password fields: font mono, type="password" with toggle visibility
            test result: inline alert component
a11y        <form> with <fieldset> per section. Labels on every input.
            Password toggle: aria-label "Show password" / "Hide password".
            Test result: aria-live="assertive".
used on     S27
```

---

## 22. Automation Control Checklist

```
layout      list of toggleable automation items grouped by type
groups      Flows, Triggers, Validation Rules, Process Builders, Workflow Rules
elements    - Group header (type + count)
            - Item row: toggle switch + API name + current state badge
states      all active (default), some toggled off (yellow warning banner at top),
            restoring (spinner on toggled items after job completes)
tokens      bg bg-raised, border border, radius lg
            toggle: Radix Switch, accent when active, surface when off
            warning banner: bg warning-light, border-left 4px warning
a11y        <fieldset> per group with <legend>. Each toggle is a Radix Switch
            with aria-label "Deactivate {apiName} during import".
            Warning banner: role="alert".
used on     S21
```

---

## 23. Flow Step List / Canvas

```
layout      vertical step list (v1), horizontal canvas with connectors (v2 future)
elements    - Step card: order number + job name + operation badge + on-error config
            - Connector line between steps (vertical, dashed)
            - Add step button (between or at end)
            - Reorder handle (drag grip icon)
states      empty ("Add your first step"), multi-step (connected cards),
            step error config open (dropdown: stop/skip/retry), running (step
            highlighted with progress)
tokens      step card: bg bg, border border, radius lg, shadow xs, padding space-4
            connector line: border-left 2px dashed border, margin-left space-6
            order badge: bg accent, text on-accent, w-7 h-7, radius pill, text-sm font-600
a11y        <ol> with <li> per step. Drag handle: aria-label "Reorder step {n}",
            aria-roledescription "draggable". On-error: <select> with label.
used on     S32
```

---

## 24. Hierarchy Tree

```
layout      indented tree with expand/collapse
elements    - Object node: expand arrow + object icon + label (API name) +
              SOQL filter badge (if set) + actions (remove, add child)
            - Indent lines (vertical + horizontal connecting lines)
            - Add child button (appears on hover or via action menu)
states      single node (root only), multi-level (2–4 levels deep),
            with SOQL filters (filter icon badge), drag-to-reorder
tokens      bg bg, border border, radius lg
            node: h-10, padding-left per level (space-6 × depth)
            expand arrow: Lucide ChevronRight, rotate 90° when expanded
            filter badge: bg accent-light, text accent, text-xs, radius pill
a11y        <ul role="tree"> with <li role="treeitem"> per node.
            aria-expanded on collapsible nodes. Level announced via aria-level.
            Keyboard: arrow keys to navigate tree, Enter to expand/collapse.
used on     S19
```

---

## 25. Toast / Alert

```
variants    success, warning, error, info
layout      fixed bottom-right stack, max 3 visible
elements    - Icon (variant-specific) + message text + optional action link + close button
states      entering (slide up + fade in), visible (5s auto-dismiss),
            dismissing (slide right + fade out), persistent (no auto-dismiss, e.g. errors)
tokens      success: bg success-light, border-left 4px success, text text
            error: bg danger-light, border-left 4px danger
            warning: bg warning-light, border-left 4px warning
            info: bg info-light, border-left 4px info
            shadow md, radius lg, padding space-4, max-w 420px
a11y        role="status" (success/info) or role="alert" (error/warning).
            aria-live="polite" or "assertive". Close button: aria-label "Dismiss".
            Focus not stolen — user stays where they were.
used on     all screens
```

---

## 26. Status Badge

```
variants    dot (small indicator), label (text badge), pill (rounded with icon)
sizes       sm (h-5 text-xs), md (h-6 text-sm)
states      active/success (green), warning (amber), error/failed (red),
            info/running (blue), neutral/inactive (gray)
tokens      dot: w-2 h-2 rounded-full
            label: px-2 py-0.5, radius pill, font-500
            success: bg success-light text success
            warning: bg warning-light text warning
            error: bg danger-light text danger
            info: bg accent-light text accent
            neutral: bg surface text-muted
a11y        Dot: aria-label for screen readers (e.g., "Status: active").
            Label: readable text, no additional aria needed.
used on     S03, S04, S12, S16, S22, S23, S25
```

---

## 27. Data Table (Generic)

```
variants    standard, compact (denser rows), sortable, selectable (checkboxes)
elements    - Header row (sticky, sortable columns with arrow indicators)
            - Data rows (alternating stripe optional)
            - Empty state (illustration + message)
            - Loading state (skeleton rows)
            - Pagination bar (page info + prev/next + page size selector)
            - Bulk action bar (appears when rows selected)
tokens      header: bg surface, text-xs text-subtle font-500 uppercase tracking-wide
            row: h-11 (standard), h-9 (compact), hover bg bg-raised
            border-bottom 1px border per row
            pagination: bg bg, border-top 1px border, padding space-3
a11y        <table> with <thead>. Sortable: <th aria-sort="ascending|descending|none">,
            <button> inside th. Selectable: <input type="checkbox"> with aria-label
            "Select row {n}" and "Select all". Pagination: <nav aria-label="Table pagination">.
used on     S03, S12, S13, S14, S16, S25, S28, S29
```

---

## 28. Modal / Dialog

```
variants    sm (480px), md (640px), lg (960px), full (90vw)
elements    - Overlay (bg black/50), modal container, header (title + close),
              body (scrollable), footer (action buttons right-aligned)
states      opening (fade + scale 0.95→1), open, closing (fade + scale 1→0.95)
tokens      bg bg, radius xl, shadow pop, padding space-6
            header: text-lg font-600, border-bottom 1px border
            footer: border-top 1px border, padding-top space-4, gap space-3
            overlay: bg rgba(0,0,0,0.5), backdrop-blur-sm
a11y        Radix Dialog. Focus trapped. aria-labelledby on title.
            Close on Escape. Return focus to trigger on close.
            Scroll lock on body.
used on     S15, S21 (inline panel), S27, S31
```

---

## 29. Tabs

```
variants    underline (default), boxed (bg switch), pill (rounded bg)
sizes       sm (text-sm h-8), md (text-base h-9)
states      active (accent underline 2px or accent bg), inactive (text-muted),
            hover (text text), disabled (text-subtle), focus-visible (ring)
tokens      underline: border-bottom 2px transparent → accent on active
            boxed: bg surface, active bg bg shadow xs
            pill: bg surface, active bg accent text on-accent, radius pill
            gap space-1 (pill/boxed), space-6 (underline)
a11y        Radix Tabs. role="tablist", role="tab", role="tabpanel".
            Arrow keys to switch. aria-selected on active tab.
used on     S12 (Results/Errors/Rollback), S16, S23
```

---

## 30. Input / Text Field

```
variants    text, password (with toggle), email, number, search (with icon)
sizes       sm (h-8 text-sm), md (h-9 text-base), lg (h-11 text-md)
states      default (border border-input), hover (border text-muted),
            focus (border accent + ring shadow-focus), error (border danger +
            ring danger/35 + error message below), disabled (bg surface opacity 50),
            readonly (bg surface-alt, no border)
tokens      bg bg, border 1px border-input, radius md, px space-3
            label: text-sm font-500 text, mb space-1.5
            helper text: text-xs text-muted, mt space-1
            error text: text-xs text danger, mt space-1
a11y        <label> linked via htmlFor. aria-describedby for helper/error text.
            aria-invalid when error. Password toggle: aria-label.
            Required: aria-required + visible asterisk.
used on     S06, S08, S09, S22, S27, S28
```

---

## 31. Select / Dropdown

```
variants    single-select, with search, with groups
sizes       sm (h-8), md (h-9), lg (h-11)
states      default (placeholder), open (shadow md, max-h 300px scroll),
            selected (value shown), error (border danger), disabled
tokens      trigger: same as Input. bg bg, border border-input, radius md
            menu: bg bg, border border, shadow md, radius md, py space-1
            item: px space-3 py space-2, hover bg bg-raised, radius sm
            selected item: bg accent-light, text accent
a11y        Radix Select. Keyboard: Space/Enter to open, arrow keys, type-ahead,
            Escape to close. aria-label on trigger.
used on     S07, S08, S17, S18, S22, S30
```

---

## 32. Switch / Toggle

```
sizes       sm (w-8 h-5), md (w-10 h-6)
states      off (bg surface-alt, thumb bg), on (bg accent, thumb on-accent),
            hover (ring shadow-focus at 50% opacity), focus-visible (ring),
            disabled (opacity 50)
tokens      track: radius pill, transition motion-base ease
            thumb: circle, shadow xs, translate-x on toggle
a11y        Radix Switch. aria-checked. aria-label required when no visible label.
            Keyboard: Space to toggle.
used on     S21, S22, S24, S30
```

---

## 33. Usage Meter / Bar Chart

```
variants    horizontal bar (single metric), stacked bar, daily trend line
elements    - Label + current/limit text (e.g., "45,230 / 100,000 API calls")
            - Bar: fill proportional to usage
            - Threshold markers at 80% (warning) and 100% (danger)
states      normal (accent fill), warning (warning fill at ≥80%), critical
            (danger fill at ≥95%), over-limit (danger + pulse animation)
tokens      track: bg surface, h-3, radius pill
            fill: bg accent → bg warning → bg danger based on threshold
a11y        role="meter" with aria-valuenow, aria-valuemin, aria-valuemax,
            aria-label "API usage: 45,230 of 100,000". Threshold alerts: aria-live.
used on     S29
```

---

## 34. Search Bar

```
variants    inline (table header), standalone (page-level)
states      empty (placeholder + Lucide Search icon), typing (clear button appears),
            results (count indicator), no results (message), loading (spinner)
tokens      bg bg, border border-input, radius md, h-9
            icon: text-subtle, left space-3. clear button: ghost icon button
            shortcut hint: text-xs text-subtle "⌘K" badge (optional)
a11y        <input type="search"> with aria-label. Clear button: aria-label "Clear search".
            Debounced (300ms). ESC to clear.
used on     S07, S16, S26
```

---

## 35. Empty State

```
variants    full-page (centered), inline (within a card/table)
elements    - Illustration (Lucide icon, 64px, text-subtle) or custom SVG
            - Title (text-lg font-600)
            - Description (text-base text-muted, max-w 400px)
            - CTA button (primary)
states      no data (default), error (danger variant), search no results
tokens      padding space-12 (full-page), space-8 (inline)
            illustration: text-subtle, opacity-60
a11y        Meaningful alt text on illustration. CTA clearly describes action.
used on     S03, S10, S16, S23, S25, S32
```

---

## 36. Wizard Stepper

```
layout      horizontal step indicator at top of wizard pages
elements    - Step circles (numbered or checkmark when complete)
            - Step labels below circles
            - Connecting lines between circles
            - Current step highlighted
states      completed (success bg, check icon), current (accent bg, number),
            upcoming (surface bg, number, text-muted)
tokens      circle: w-8 h-8, radius pill, font-sm font-600
            line: h-0.5, bg border (upcoming), bg success (completed)
            label: text-xs, mt space-2
a11y        <ol> with aria-label "Import wizard steps". Current: aria-current="step".
            Completed: aria-label "Step 1: Select source, completed".
used on     S05–S10 (import wizard), S17–S20 (migration wizard), S24 (backup)
```

---

## Layout Patterns

### App Shell

```
┌──────────────────────────────────────────────────────┐
│ Header (h-14, fixed top, z-sticky)                   │
├──────────┬───────────────────────────────────────────┤
│ Sidebar  │ Main content area                         │
│ (w-60,   │ (ml-60, pt-14, px-6, max-w content-max)  │
│ fixed,   │                                           │
│ full-h,  │                                           │
│ z-sticky)│                                           │
└──────────┴───────────────────────────────────────────┘
```

### Wizard Layout

```
Main content area:
┌──────────────────────────────────────────────────────┐
│ Wizard Stepper (centered, max-w wizard-max)          │
├──────────────────────────────────────────────────────┤
│ Step content (centered, max-w wizard-max, py-6)      │
│                                                      │
│                                                      │
├──────────────────────────────────────────────────────┤
│ Footer: Back (secondary) ──────── Next (primary)     │
└──────────────────────────────────────────────────────┘
```

### Dashboard Layout

```
Main content area:
┌──────────────────────────────────────────────────────┐
│ Page title + Quick action buttons (right-aligned)     │
├──────────────────────────────────────────────────────┤
│ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐    │
│ │ Stat    │ │ Stat    │ │ Stat    │ │ Stat    │    │
│ │ Card    │ │ Card    │ │ Card    │ │ Card    │    │
│ └─────────┘ └─────────┘ └─────────┘ └─────────┘    │
├──────────────────────────────────────────────────────┤
│ Recent Jobs Table (full width, paginated)             │
│                                                      │
└──────────────────────────────────────────────────────┘
```

---

## Icon Set

**Library:** Lucide React (MIT license)
**Size:** 20px for inline, 24px for buttons, 48–64px for empty states
**Stroke:** 1.5px (default Lucide)

| purpose           | icon name         | usage                      |
| ----------------- | ----------------- | -------------------------- |
| Import / upload   | `Upload`          | S05, S06, file dropzone    |
| Export / download | `Download`        | S12, results CSV           |
| Salesforce org    | `Cloud`           | S04, org selector          |
| CSV file          | `FileSpreadsheet` | S05, source selection      |
| Database          | `Database`        | S05, S27, DB connectors    |
| SFTP              | `Server`          | S05, S27                   |
| Mapping / link    | `Link2`           | S08, lookup fields         |
| Formula           | `Function`        | S08, S09                   |
| Filter            | `Filter`          | S09, S17                   |
| Schedule / clock  | `Clock`           | S22                        |
| Backup / shield   | `ShieldCheck`     | S23, S24                   |
| Restore / undo    | `RotateCcw`       | S26, rollback              |
| Flow / pipeline   | `GitBranch`       | S32                        |
| Settings          | `Settings`        | settings nav               |
| Team / users      | `Users`           | S28                        |
| Notifications     | `Bell`            | header                     |
| Search            | `Search`          | search bars                |
| Check / success   | `CheckCircle2`    | success states             |
| Warning           | `AlertTriangle`   | warnings, partial failures |
| Error             | `XCircle`         | error states               |
| Delete / trash    | `Trash2`          | delete actions             |
| Edit / pencil     | `Pencil`          | edit actions               |
| Plus / add        | `Plus`            | add buttons                |
| Chevron           | `ChevronRight`    | tree expand, breadcrumbs   |
| Menu / hamburger  | `Menu`            | sidebar toggle             |
| Drag handle       | `GripVertical`    | reorder handles            |
| Eye / preview     | `Eye`             | preview, password toggle   |
| API / code        | `Code2`           | S29, API usage             |
