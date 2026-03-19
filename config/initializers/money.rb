Rails.application.config.after_initialize do
  Rails.logger.info "Money module loaded with #{Money::CURRENCY_SYMBOLS.keys.count} currencies"
end
