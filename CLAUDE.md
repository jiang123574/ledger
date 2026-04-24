# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ledger is a personal finance tracking system built with Ruby on Rails 8 + Hotwire (Turbo + Stimulus) + Tailwind CSS v4. It supports multiple transaction types, account management, budgets, and reporting with a mobile-first UI.

## Commands

### Development Server
```bash
bin/rails server -b 0.0.0.0 -p 3000  # Bind to 0.0.0.0 for mobile/Android access
# Or use foreman for Tailwind watch + Rails server:
bin/dev
```

### Database
```bash
bin/rails db:migrate              # Run migrations
bin/rails db:migrate:status       # Check migration status
```

### Testing
```bash
bundle exec rspec                          # Run all tests
bundle exec rspec spec/models/entry_spec.rb  # Run single file
bundle exec rspec spec/models/entry_spec.rb:10  # Run specific line
```

### Linting & Security
```bash
bundle exec rubocop      # Ruby style check
bundle exec brakeman     # Security vulnerability scan
```

### Account Cache Update
```bash
bin/rails runner "Account.bulk_update_cache"  # Update counter cache for all accounts
```

## Architecture

### Entry Model (Delegated Type Pattern)

The core of the finance system. `Entry` is a unified model using Rails delegated_type to support multiple transaction types:

- `Entryable::Transaction` - Regular transactions (income/expense) with category and tags
- `Entryable::Trade` - Investment trades (buy/sell securities)
- `Entryable::Valuation` - Asset valuations at a specific date

Key scopes: `Entry.expenses`, `Entry.incomes`, `Entry.transactions_only`, `Entry.chronological`

When working with Entry, always consider which entryable type it represents - check `entry.transaction?`, `entry.valuation?`, or `entry.trade?`.

### Account Model

Account types: `CASH`, `BANK`, `CREDIT`, `INVESTMENT`, `LOAN`, `DEBT`

Credit card accounts have billing cycle logic (`bill_cycle_for`, `bill_cycles_with_statement`). Use `Account.visible.included_in_total` for aggregate calculations.

### Stimulus Controllers

All JS interactivity uses Stimulus. Controllers are in `app/javascript/controllers/`. Each controller is registered in `config/importmap.rb` with explicit pin declarations.

Controller naming convention: `snake_case_controller.js` → registered as `"snake-case"` in importmap.

Important controllers:
- `native_bridge_controller` - Android app integration via `window.LedgerNative`
- `select_controller` - Custom dropdown with search
- `list_filter_controller` - Search/filter for lists
- `menu_controller` - Dropdown menus using @floating-ui/dom
- `tooltip_controller` - Tooltips using @floating-ui/dom

### ViewComponent Design System

UI components in `app/components/ds/` (21 components). Base class: `Ds::BaseComponent`.

Usage pattern:
```erb
render(Ds::ButtonComponent.new(variant: :primary, icon: "plus"))
render(Ds::MenuComponent.new(placement: "bottom-end")) { |menu| ... }
```

### Importmap Configuration

JavaScript modules are managed via `config/importmap.rb`. Vendor packages (@hotwired/stimulus, @floating-ui/dom, Chart.js) are vendored in `app/javascript/` for production reliability.

When adding a new Stimulus controller:
1. Create `app/javascript/controllers/my_controller.js`
2. Add pin in `config/importmap.rb`: `pin "controllers/my_controller", to: "controllers/my_controller.js"`
3. Import and register in `app/javascript/controllers/index.js`

### Turbo/Inline JS Considerations

Turbo page replacements re-execute inline `<script>` tags, causing duplicate `const/let` declaration errors. Wrap inline scripts in IIFE:
```erb
<script>
(function() {
  const myVar = 'value';
  // ...
})();
</script>
```

Or use `<script type="module">` which has natural scope isolation.

## Key Patterns

### Preloading Transfer Accounts

Entry has `Entry.preload_transfer_accounts(entries)` to batch-load transfer pairing accounts, avoiding N+1 queries when rendering transfer entries.

### Account Stats

`AccountDashboardService` handles dashboard aggregation. See `docs/ACCOUNT_DASHBOARD_SERVICE.md` for details.

### Pinyin Search

Uses `ruby-pinyin` gem. The `PinYin.abbr(text)` method returns first-letter abbreviations for Chinese text. See `docs/PINYIN_SELECTOR_GUIDE.md` for the selector component.

### Native App Integration

The Android app injects `window.LedgerNative` for native features (file picker, share, biometric). Check `NativeApp.isNative` before calling native methods.

## Services

Business logic in `app/services/`:
- `EntryCreationService` - Transaction creation with validation
- `BackupService` - Database backup/restore with WebDAV
- `ImportService` - CSV/Excel/OFX/QIF import
- `PixiuImportService` - Import from Pixiu app format

## External API

`/api/external` endpoints for external integrations. Requires `EXTERNAL_API_KEY` env var. See `docs/API.md` for full endpoint list.

## Ruby Version

Ruby 3.3.10 via Homebrew. Full path: `/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/ruby`


Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.