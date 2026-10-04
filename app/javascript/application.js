// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "agenda_loading"
import "trip_multi_location"
import "avatar_upload"

// Change to true to allow Turbo
Turbo.session.drive = false

document.addEventListener("click", function (event) {
  const openPlan = event.target.closest("[data-nalu-open-plan]")
  if (openPlan) {
    event.preventDefault()
    const planTab = document.getElementById("tab-plan")
    if (planTab) {
      planTab.click()
      window.scrollTo({ top: 0, behavior: "smooth" })
    } else {
      window.location.assign("/#plan")
    }
    return
  }
}, true)

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

document.addEventListener("click", function (event) {
  const link = event.target.closest("a[data-delete-confirm]")
  if (!link) return

  const href = link.getAttribute("href")
  const message = link.getAttribute("data-delete-confirm")
  if (!href || !message) return

  event.preventDefault()
  event.stopPropagation()

  let dialog = document.getElementById("app-confirm-dialog")
  if (!dialog) {
    dialog = document.createElement("dialog")
    dialog.id = "app-confirm-dialog"
    dialog.className = "app-confirm-dialog"
    dialog.innerHTML =
      "<article>" +
      '<p class="app-confirm-dialog__msg"></p>' +
      "<footer>" +
      '<button type="button" class="secondary app-confirm-dialog__cancel">Cancel</button>' +
      '<button type="button" class="app-confirm-dialog__ok">Delete</button>' +
      "</footer>" +
      "</article>"
    document.body.appendChild(dialog)
  }

  dialog.querySelector(".app-confirm-dialog__msg").textContent = message
  const ok = dialog.querySelector(".app-confirm-dialog__ok")
  const cancel = dialog.querySelector(".app-confirm-dialog__cancel")

  const close = function () {
    if (typeof dialog.close === "function") dialog.close()
    else dialog.removeAttribute("open")
  }

  cancel.onclick = close
  ok.onclick = function () {
    close()
    if (link.getAttribute("data-delete-inplace") === "true") {
      deleteTripInPlace(link, href)
    } else {
      window.location.assign(href)
    }
  }

  if (typeof dialog.showModal === "function") dialog.showModal()
  else if (link.getAttribute("data-delete-inplace") === "true") deleteTripInPlace(link, href)
  else window.location.assign(href)
}, true)

function deleteTripInPlace(link, href) {
  const row = link.closest("li")
  fetch(href, {
    method: "GET",
    credentials: "same-origin",
    headers: {
      Accept: "application/json",
      "X-Requested-With": "XMLHttpRequest"
    }
  }).then(function (res) {
    if (!res.ok) throw new Error("delete failed")
    if (!row) {
      window.location.assign("/")
      return
    }
    const list = row.parentElement
    row.remove()
    if (list && !list.querySelector("li")) {
      const wrap = list.closest(".trips-list-wrap")
      if (wrap) {
        const template = document.getElementById("future-trips-empty-template")
        if (list.id === "future-trips-list" && template) {
          wrap.classList.add("trips-list-wrap--empty")
          wrap.replaceChildren(template.content.cloneNode(true))
        } else {
          const empty = document.createElement("p")
          empty.className = "trips-list-empty"
          empty.textContent = "No trips yet."
          wrap.replaceChildren(empty)
        }
      }
    }
  }).catch(function () {
    window.location.assign(href)
  })
}


