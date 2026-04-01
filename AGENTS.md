# AGENTS Configuration

## Ruby Environment

This project uses Ruby 3.3.10 installed via Homebrew.

### Ruby Path
```
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/ruby
```

### Bundle Path
```
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/bundle
```

### Rails Path
```
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails
```

## Development Setup

To run Rails commands with the correct Ruby version:

```bash
# Run migrations
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails db:migrate

# Run Rails runner
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails runner "Account.bulk_update_cache"

# Start Rails server
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails server
```

Or add to your shell PATH:

```bash
export PATH="/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin:$PATH"
```

## Project-specific Commands

### Database Migrations
After creating new migrations, run:
```bash
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails db:migrate
```

### Update Account Cache
To update counter cache for all accounts:
```bash
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails runner "Account.bulk_update_cache"
```

### Testing
```bash
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/rails test
```

### Linting
```bash
/opt/homebrew/Cellar/ruby@3.3/3.3.10/bin/bundle exec rubocop
```