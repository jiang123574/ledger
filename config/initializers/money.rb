Rails.application.config.after_initialize do
  symbols_count = defined?(Currency::CURRENCY_SYMBOLS) ? Currency::CURRENCY_SYMBOLS.keys.count : 0
  Rails.logger.info "Money module loaded with #{symbols_count} currencies"
end
