# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
pin "@rails/ujs", to: "@rails--ujs.js" # @7.1.3
pin "jquery" # @3.7.1
pin "agenda_loading"
pin "avatar_upload"
pin "heic2any", to: "https://cdn.jsdelivr.net/npm/heic2any@0.0.4/dist/heic2any.min.js"
