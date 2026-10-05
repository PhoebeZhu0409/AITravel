// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "agenda_loading"
import "trip_multi_location"
import "avatar_upload"

// Change to true to allow Turbo
Turbo.session.drive = false

function csrfToken() {
  const meta = document.querySelector('meta[name="csrf-token"]')
  return meta ? meta.getAttribute("content") : ""
}

function applySavedSpotState(button, saved) {
  button.setAttribute("data-saved", saved ? "true" : "false")
  button.setAttribute("aria-pressed", saved ? "true" : "false")
  button.setAttribute("aria-label", saved ? "Remove from saved spots" : "Save spot")
  button.classList.toggle("agenda-save-spot--saved", saved)
  const icon = button.querySelector(".bi")
  if (icon) {
    icon.classList.toggle("bi-bookmark-fill", saved)
    icon.classList.toggle("bi-bookmark", !saved)
  }
}

document.addEventListener("click", function (event) {
  const saveBtn = event.target.closest(".agenda-save-spot")
  if (saveBtn) {
    event.preventDefault()
    event.stopPropagation()

    const id = saveBtn.getAttribute("data-trip-plan-id")
    const saved = saveBtn.getAttribute("data-saved") === "true"
    const method = saved ? "DELETE" : "POST"

    fetch("/saved_spots/" + id, {
      method: method,
      credentials: "same-origin",
      headers: {
        Accept: "application/json",
        "X-Requested-With": "XMLHttpRequest",
        "X-CSRF-Token": csrfToken()
      }
    }).then(function (res) {
      if (!res.ok) throw new Error("save failed")
      return res.json()
    }).then(function (data) {
      const nowSaved = !!data.saved
      document.querySelectorAll('.agenda-save-spot[data-trip-plan-id="' + id + '"]').forEach(function (btn) {
        applySavedSpotState(btn, nowSaved)
      })

      if (!nowSaved) {
        const card = saveBtn.closest(".saved-spot-card, article.saved-spot-card")
        if (card) {
          const li = card.closest("li")
          const group = card.closest("[data-saved-city]")
          const wrap = card.closest(".saved-spots-list-wrap")
          const city = group && group.getAttribute("data-saved-city")
          if (li) li.remove()
          const list = group && group.querySelector(".saved-spots-list")
          if (group && list && !list.querySelector("li")) {
            group.remove()
            const filter = wrap && wrap.querySelector("#saved-spots-city-filter")
            if (filter && city) {
              Array.from(filter.options).forEach(function (opt) {
                if (opt.value === city) opt.remove()
              })
              if (filter.value === city) {
                filter.value = ""
                filter.dispatchEvent(new Event("change"))
              }
            }
          }
          if (wrap && !wrap.querySelector("[data-saved-city]")) {
            wrap.innerHTML =
              "<p class=\"saved-spots-empty\">No saved spots yet. Open a trip agenda and tap the bookmark on any stop to save it here.</p>"
          }
        }
      }
    }).catch(function () {})

    return
  }
}, true)

document.addEventListener("change", function (event) {
  const filter = event.target.closest("#saved-spots-city-filter")
  if (!filter) return

  const wrap = filter.closest(".saved-spots-list-wrap")
  if (!wrap) return

  const city = filter.value
  wrap.querySelectorAll("[data-saved-city]").forEach(function (group) {
    group.hidden = !!(city && group.getAttribute("data-saved-city") !== city)
  })
})

const savedSpotNoteSaveTimers = new WeakMap()

function scheduleSavedSpotNoteSave(textarea) {
  const id = textarea.getAttribute("data-trip-plan-id")
  if (!id) return

  const prev = savedSpotNoteSaveTimers.get(textarea)
  if (prev) clearTimeout(prev)

  savedSpotNoteSaveTimers.set(
    textarea,
    setTimeout(function () {
      fetch("/saved_spots/" + id, {
        method: "PATCH",
        credentials: "same-origin",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-Requested-With": "XMLHttpRequest",
          "X-CSRF-Token": csrfToken()
        },
        body: JSON.stringify({ traveller_note: textarea.value })
      }).catch(function () {})
    }, 450)
  )
}

document.addEventListener("input", function (event) {
  const textarea = event.target.closest("[data-saved-spot-note]")
  if (textarea) scheduleSavedSpotNoteSave(textarea)
})

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
