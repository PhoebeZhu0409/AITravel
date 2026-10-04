// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "agenda_loading"
import "trip_multi_location"
import "avatar_upload"

// Change to true to allow Turbo
Turbo.session.drive = false

document.addEventListener("click", function (event) {
  const back = event.target.closest("a.web-back-link")
  if (back && window.history.length > 1) {
    event.preventDefault()
    window.history.back()
  }
}, true)

// Envoy / mobile WebViews: break out of iframe so navigation is not saved as document.txt
document.addEventListener("click", function (event) {
  if (window.self === window.top) return

  const link = event.target.closest("a[href]")
  if (!link || link.target === "_blank" || link.hasAttribute("download")) return

  const href = link.getAttribute("href")
  if (!href || href.startsWith("#") || href.startsWith("mailto:") || href.startsWith("tel:")) return

  let url
  try {
    url = new URL(link.href, window.location.href)
  } catch {
    return
  }

  if (url.origin !== window.location.origin) return

  event.preventDefault()
  window.top.location.assign(url.href)
}, true)

// Allow UJS alongside Turbo
import jquery from "jquery";
window.jQuery = jquery;
window.$ = jquery;
import Rails from "@rails/ujs"
Rails.start();


