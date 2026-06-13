# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Ledger is a personal finance tracking system built with Ruby on Rails 8.1 + Hotwire (Turbo + Stimulus) + Tailwind CSS v4. It supports multiple transaction types, account management, budgets, and reporting with a mobile-first UI.

Single-user local network app. Security requirements are low.

## Commands

### Development Server
```bash
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails server -b 0.0.0.0 -p 3000
```

### Database
```bash
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails db:migrate
```

### Testing
```bash
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/bundle exec rspec
```

### Linting
```bash
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/bundle exec rubocop
```

### CI Failure Handling
If CI fails, evaluate whether the test accurately assesses the code. If the test is outdated, update the test.

## Language

优先使用中文输出

## Architecture

### Entry Model (Delegated Type Pattern)

The core of the finance system. `Entry` is a unified model using Rails delegated_type:

- `Entryable::Transaction` - Regular transactions (income/expense) with category
- `Entryable::Trade` - Investment trades
- `Entryable::Valuation` - Asset valuations

Key scopes: `Entry.expenses`, `Entry.incomes`, `Entry.transactions_only`, `Entry.chronological`

### Account Model

Account types: `CASH`, `BANK`, `CREDIT`, `INVESTMENT`, `LOAN`, `DEBT`

Credit card accounts have billing cycle logic. Use `Account.visible.included_in_total` for aggregate calculations.

### Stimulus Controllers

All JS interactivity uses Stimulus. Controllers in `app/javascript/controllers/`.

Controller naming: `snake_case_controller.js` → registered as `"snake-case"` in importmap.

### Importmap Configuration

JavaScript modules managed via `config/importmap.rb`. Vendor packages vendored in `app/javascript/`.

When adding a new Stimulus controller:
1. Create `app/javascript/controllers/my_controller.js`
2. Add pin in `config/importmap.rb`
3. Import and register in `app/javascript/controllers/index.js`

### Turbo/Inline JS Considerations

Turbo page replacements re-execute inline `<script>` tags. Wrap in IIFE:
```erb
<script>
(function() {
  const myVar = 'value';
})();
</script>
```

## Key Patterns

### Entry.preload_transfer_accounts

Batch-load transfer pairing accounts to avoid N+1 queries.

### Pinyin Search

Uses `ruby-pinyin` gem. See `docs/PINYIN_SELECTOR_GUIDE.md`.

### Native App Integration

Android app injects `window.LedgerNative`. Check `NativeApp.isNative` before calling native methods.

## Services

- `EntryCreationService` - Transaction creation
- `BackupService` - Database backup/restore with WebDAV
- `ImportService` - CSV/Excel/OFX/QIF import
- `PixiuImportService` - Pixiu app format import
- `ReportGenerationService` - Report data computation

## External API

`/api/v1/external` endpoints. Requires `EXTERNAL_API_KEY` env var. See `docs/API.md`.

## Ruby Version

Ruby 3.3.10 via Homebrew. Path: `/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/ruby`

## Coding Guidelines

1. **Think Before Coding** - State assumptions, surface tradeoffs
2. **Simplicity First** - Minimum code that solves the problem
3. **Surgical Changes** - Touch only what you must
4. **Goal-Driven Execution** - Define success criteria, verify before done
