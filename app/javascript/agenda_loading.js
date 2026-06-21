// Loading overlay for AI agenda generation (estimated progress — server has no real %).
(function () {
  var progressTimer = null;
  var ESTIMATED_MS = 45000;
  var DEFAULT_MAX_TRIP_DAYS = 21;
  var DEFAULT_LONG_TRIP_WARNING_DAYS = 10;

  function formatYmd(date) {
    var y = date.getFullYear();
    var m = String(date.getMonth() + 1).padStart(2, "0");
    var d = String(date.getDate()).padStart(2, "0");
    return y + "-" + m + "-" + d;
  }

  function addDays(date, days) {
    var copy = new Date(date.getTime());
    copy.setDate(copy.getDate() + days);
    return copy;
  }

  function tripDurationDays(start, end) {
    return Math.floor((end - start) / 86400000) + 1;
  }

  function maxTripDaysFor(form) {
    return Number(form.dataset.maxTripDays || DEFAULT_MAX_TRIP_DAYS);
  }

  function longTripWarningDaysFor(form) {
    return Number(form.dataset.longTripWarningDays || DEFAULT_LONG_TRIP_WARNING_DAYS);
  }

  function durationWarningEl(form) {
    return document.getElementById(form.id + "-duration-warning");
  }

  function longTripWarningMessage(days, warnDays) {
    return (
      "Your trip is " + days + " days. Trips longer than " + warnDays +
      " days may take extra time to build."
    );
  }

  function maxTripLimitMessage(days, maxDays) {
    return (
      "Your trip is " + days + " days. We can't build trips longer than " + maxDays +
      " days — please choose a shorter end date."
    );
  }

  function maxTripLimitSubmitError(maxDays) {
    return "We can't build trips longer than " + maxDays + " days.";
  }

  function updateTripDateConstraints(form) {
    var maxDays = maxTripDaysFor(form);
    var warnDays = longTripWarningDaysFor(form);
    var startEl = form.querySelector("[name='query_trip_start_date']");
    var endEl = form.querySelector("[name='query_trip_end_date']");
    var warnEl = durationWarningEl(form);
    if (!startEl || !endEl) return;

    var startStr = startEl.value;
    if (startStr) {
      endEl.min = startStr;
      var startDate = parseYmd(startStr);
      if (startDate) {
        endEl.max = formatYmd(addDays(startDate, maxDays - 1));
      }
    } else {
      endEl.removeAttribute("min");
      endEl.removeAttribute("max");
    }

    if (!warnEl) return;

    warnEl.classList.remove("trip-duration-warning--limit");

    if (endEl.value.trim() && !parseYmd(endEl.value)) {
      warnEl.textContent = "Please enter a valid trip end date.";
      warnEl.classList.add("trip-duration-warning--limit");
      warnEl.removeAttribute("hidden");
      return;
    }

    var start = parseYmd(startStr);
    var end = parseYmd(endEl.value);

    if (!start || !end || end < start) {
      warnEl.setAttribute("hidden", "");
      warnEl.textContent = "";
      return;
    }

    var days = tripDurationDays(start, end);
    if (days > maxDays) {
      warnEl.textContent = maxTripLimitMessage(days, maxDays);
      warnEl.classList.add("trip-duration-warning--limit");
      warnEl.removeAttribute("hidden");
      return;
    }

    if (days > warnDays) {
      warnEl.textContent = longTripWarningMessage(days, warnDays);
      warnEl.removeAttribute("hidden");
      return;
    }

    warnEl.setAttribute("hidden", "");
    warnEl.textContent = "";
  }

  function wireTripDateFields(formId) {
    var form = document.getElementById(formId);
    if (!form || form.dataset.tripDatesWired === "true") return;

    form.dataset.tripDatesWired = "true";
    var startEl = form.querySelector("[name='query_trip_start_date']");
    var endEl = form.querySelector("[name='query_trip_end_date']");
    if (!startEl || !endEl) return;

    function onChange() {
      updateTripDateConstraints(form);
    }

    startEl.addEventListener("change", onChange);
    endEl.addEventListener("change", onChange);
    onChange();
  }

  function parseYmd(str) {
    if (!str || !String(str).trim()) return null;
    var parts = String(str).trim().split("-");
    if (parts.length !== 3) return null;
    var y = Number(parts[0]);
    var m = Number(parts[1]);
    var d = Number(parts[2]);
    if (!y || !m || !d) return null;
    var date = new Date(y, m - 1, d);
    if (
      date.getFullYear() !== y ||
      date.getMonth() !== m - 1 ||
      date.getDate() !== d
    ) {
      return null;
    }
    return date;
  }

  function todayLocal() {
    var t = new Date();
    return new Date(t.getFullYear(), t.getMonth(), t.getDate());
  }

  function validateTripAgendaForm(form) {
    var errors = [];
    var submitBtn = form.querySelector("[type='submit']");
    if (submitBtn && submitBtn.disabled) {
      errors.push("You have reached your trip generation limit.");
      return errors;
    }

    var nameEl = form.querySelector("[name='query_trip_name']");
    var locationEl = form.querySelector("[name='query_trip_location']");
    var startEl = form.querySelector("[name='query_trip_start_date']");
    var endEl = form.querySelector("[name='query_trip_end_date']");

    var name = (nameEl && nameEl.value) || "";
    var location = (locationEl && locationEl.value) || "";
    var startStr = (startEl && startEl.value) || "";
    var endStr = (endEl && endEl.value) || "";

    if (!name.trim()) errors.push("Trip name can't be blank");
    if (!location.trim()) errors.push("Trip location can't be blank");

    if (!startStr.trim()) errors.push("Trip start date can't be blank");
    if (!endStr.trim()) errors.push("Trip end date can't be blank");

    var start = parseYmd(startStr);
    var end = parseYmd(endStr);
    var today = todayLocal();

    if (startStr.trim() && !start) {
      errors.push("Please enter valid trip start and end dates.");
    }
    if (endStr.trim() && !end) {
      errors.push("Please enter a valid trip end date.");
    }

    if (start && start <= today) {
      errors.push("Trip start date cannot be in the past");
    }

    if (start && end && end < start) {
      errors.push("Trip end must be on or after trip start.");
    }

    if (start && end && end >= start) {
      var maxDays = maxTripDaysFor(form);
      var days = tripDurationDays(start, end);
      if (days <= 0) {
        errors.push("Trip duration days is not a number");
      } else if (days > maxDays) {
        errors.push(maxTripLimitSubmitError(maxDays));
      }
    }

    return errors;
  }

  function formErrorsEl(form) {
    return document.getElementById(form.id + "-errors");
  }

  function showFormErrors(form, errors) {
    var el = formErrorsEl(form);
    if (!el) return;

    el.textContent = errors.join(" ");
    el.removeAttribute("hidden");
    el.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }

  function hideFormErrors(form) {
    var el = formErrorsEl(form);
    if (!el) return;
    el.textContent = "";
    el.setAttribute("hidden", "");
  }

  function lockPageScroll() {
    document.documentElement.classList.add("agenda-loading-active");
    document.body.classList.add("agenda-loading-active");
  }

  function hideAgendaLoading() {
    var overlay = document.getElementById("agenda-loading-overlay");
    if (progressTimer) {
      clearInterval(progressTimer);
      progressTimer = null;
    }
    if (!overlay) return;
    overlay.setAttribute("hidden", "");
    overlay.setAttribute("aria-hidden", "true");
    document.documentElement.classList.remove("agenda-loading-active");
    document.body.classList.remove("agenda-loading-active");
  }

  function showAgendaLoading() {
    var overlay = document.getElementById("agenda-loading-overlay");
    if (!overlay) return;

    lockPageScroll();

    overlay.removeAttribute("hidden");
    overlay.setAttribute("aria-hidden", "false");

    var percentEl = document.getElementById("agenda-loading-percent");
    var surferMover = document.getElementById("agenda-surfer-mover");
    if (!percentEl) return;

    if (progressTimer) clearInterval(progressTimer);

    if (surferMover) {
      surferMover.style.left = "6%";
    }

    var startTime = Date.now();

    function tick() {
      var elapsed = Date.now() - startTime;
      var t = elapsed / ESTIMATED_MS;
      var pct = Math.floor(95 * (1 - Math.exp(-2.8 * t)));
      pct = Math.min(95, Math.max(0, pct));

      percentEl.textContent = pct + "%";
      overlay.setAttribute("aria-label", "Customizing agenda, " + pct + " percent complete");

      if (surferMover) {
        var travel = 6 + (pct / 100) * 88;
        surferMover.style.left = travel + "%";
      }
    }

    tick();
    progressTimer = setInterval(tick, 350);
  }

  function handleAgendaFormSubmit(ev) {
    var form = ev.target;
    if (!form || form.tagName !== "FORM") return;

    var errors = validateTripAgendaForm(form);
    if (errors.length) {
      ev.preventDefault();
      ev.stopPropagation();
      showFormErrors(form, errors);
      return;
    }

    hideFormErrors(form);
    showAgendaLoading();
  }

  function wireAgendaLoadingForm(formId) {
    var form = document.getElementById(formId);
    if (!form || form.dataset.agendaLoadingWired === "true") return;

    form.dataset.agendaLoadingWired = "true";
    form.addEventListener("submit", handleAgendaFormSubmit);
  }

  function initAgendaLoading() {
    wireAgendaLoadingForm("plan-trip-form");
    wireAgendaLoadingForm("rebuild-agenda-form");
    wireTripDateFields("plan-trip-form");
    wireTripDateFields("rebuild-agenda-form");

    if (!window.__agendaLoadingTurboSubmit) {
      window.__agendaLoadingTurboSubmit = true;
      document.addEventListener("turbo:submit-start", function (ev) {
        var el = ev.detail && ev.detail.formSubmission && ev.detail.formSubmission.formElement;
        if (!el) return;
        if (el.id !== "plan-trip-form" && el.id !== "rebuild-agenda-form") return;

        var errors = validateTripAgendaForm(el);
        if (errors.length) {
          ev.preventDefault();
          showFormErrors(el, errors);
          return;
        }

        hideFormErrors(el);
        showAgendaLoading();
      });
    }
  }

  document.addEventListener("DOMContentLoaded", initAgendaLoading);
  document.addEventListener("turbo:load", initAgendaLoading);
  document.addEventListener("turbo:before-visit", hideAgendaLoading);
  window.addEventListener("pagehide", hideAgendaLoading);
  window.addEventListener("pageshow", hideAgendaLoading);
})();
