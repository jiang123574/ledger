# Pin npm packages by running ./bin/importmap

pin "application"
pin "web_vitals"
pin_all_from "app/javascript/controllers", under: "controllers"

# Hotwire via jspm.io
pin "@hotwired/stimulus", to: "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/dist/stimulus.js"
pin "@hotwired/turbo", to: "https://cdn.jsdelivr.net/npm/@hotwired/turbo@8.0.4/dist/turbo.es2017-esm.js"
pin "@hotwired/turbo-rails", to: "https://cdn.jsdelivr.net/npm/@hotwired/turbo-rails@8.0.4/app/javascript/turbo/index.js"

# Stimulus loading helper
pin "@hotwired/stimulus-loading", to: "https://cdn.jsdelivr.net/npm/@hotwired/stimulus-loading@1.0.0/dist/stimulus-loading.js"

# Floating UI for positioning
pin "@floating-ui/core", to: "https://cdn.jsdelivr.net/npm/@floating-ui/core@1.6.0/dist/floating-ui.core.mjs"
pin "@floating-ui/dom", to: "https://cdn.jsdelivr.net/npm/@floating-ui/dom@1.6.0/dist/floating-ui.dom.mjs"
