// Loading overlay for AI agenda generation (estimated progress — server has no real %).
(function () {
  var progressTimer = null;
  var pollTimer = null;
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

  function legDateRange(form, startName, endName) {
    var startEl = form.querySelector("[name='" + startName + "']");
    var endEl = form.querySelector("[name='" + endName + "']");
    if (!startEl || !endEl) return null;
    var start = parseYmd(startEl.value);
    var end = parseYmd(endEl.value);
    if (!start || !end) return null;
    return { start: start, end: end };
  }

  function requiredLeg2StartDate(form) {
    var leg1 = legDateRange(form, "query_trip_start_date", "query_trip_end_date");
    if (!leg1) return null;
    return addDays(leg1.end, 1);
  }

  function leg2StartDateError(form) {
    var leg2Block = form.querySelector("#trip-leg-second");
    var leg2Visible = leg2Block && !leg2Block.hasAttribute("hidden");
    var loc2 = form.querySelector("[name='query_trip_location_2']");
    if (!leg2Visible || !loc2 || !loc2.value.trim()) return null;

    var required = requiredLeg2StartDate(form);
    var leg2StartEl = form.querySelector("[name='query_trip_start_date_2']");
    if (!required || !leg2StartEl || !leg2StartEl.value.trim()) return null;

    var leg2Start = parseYmd(leg2StartEl.value);
    if (!leg2Start) return null;

    if (formatYmd(leg2Start) !== formatYmd(required)) {
      return (
        "Second location must start on " + formatYmd(required) +
        " (the day after the first location ends)."
      );
    }
    return null;
  }

  function formatDateDisplayFromYmd(ymd) {
    var d = parseYmd(ymd);
    if (!d) return "—";
    var m = String(d.getMonth() + 1).padStart(2, "0");
    var day = String(d.getDate()).padStart(2, "0");
    return m + "/" + day + "/" + d.getFullYear();
  }

  function syncSecondLegStartDate(form) {
    var leg2Block = form.querySelector("#trip-leg-second");
    if (!leg2Block || leg2Block.hasAttribute("hidden")) return;

    var required = requiredLeg2StartDate(form);
    var leg2StartEl = form.querySelector("[name='query_trip_start_date_2']");
    var leg2Display = form.querySelector("#trip_start_date_display_2");
    if (!leg2StartEl) return;

    if (!required) {
      leg2StartEl.value = "";
      if (leg2Display) leg2Display.textContent = "—";
      return;
    }

    var ymd = formatYmd(required);
    leg2StartEl.value = ymd;
    if (leg2Display) leg2Display.textContent = formatDateDisplayFromYmd(ymd);
  }

  function overallTripRange(form) {
    var leg1 = legDateRange(form, "query_trip_start_date", "query_trip_end_date");
    if (!leg1) return null;

    var loc2 = form.querySelector("[name='query_trip_location_2']");
    var leg2Block = form.querySelector("#trip-leg-second");
    var leg2Visible = leg2Block && !leg2Block.hasAttribute("hidden");
    var leg2Loc = loc2 && loc2.value.trim();
    if (!leg2Visible || !leg2Loc) return leg1;

    var leg2 = legDateRange(form, "query_trip_start_date_2", "query_trip_end_date_2");
    if (!leg2) return leg1;

    return { start: leg1.start, end: leg2.end };
  }

  function updateTripDateConstraints(form) {
    var maxDays = maxTripDaysFor(form);
    var warnDays = longTripWarningDaysFor(form);
    var startEl = form.querySelector("[name='query_trip_start_date']");
    var endEl = form.querySelector("[name='query_trip_end_date']");
    var warnEl = durationWarningEl(form);
    if (!startEl || !endEl) return;

    // Do not set min/max on the end input — mobile browsers clear the field when
    // the value falls outside the range (often while the user is still picking a date).
    endEl.removeAttribute("min");
    endEl.removeAttribute("max");

    if (!warnEl) return;

    warnEl.classList.remove("trip-duration-warning--limit");

    if (endEl.value.trim() && !parseYmd(endEl.value)) {
      warnEl.textContent = "Please enter a valid trip end date.";
      warnEl.classList.add("trip-duration-warning--limit");
      warnEl.removeAttribute("hidden");
      return;
    }

    var start = parseYmd(startEl.value);
    var end = parseYmd(endEl.value);

    if (start && end && end < start) {
      warnEl.textContent = "Trip end must be on or after trip start.";
      warnEl.classList.add("trip-duration-warning--limit");
      warnEl.removeAttribute("hidden");
      return;
    }

    var leg2StartEl = form.querySelector("[name='query_trip_start_date_2']");
    var leg2EndEl = form.querySelector("[name='query_trip_end_date_2']");
    if (leg2StartEl && leg2EndEl) {
      var leg2Start = parseYmd(leg2StartEl.value);
      var leg2End = parseYmd(leg2EndEl.value);
      if (leg2Start && leg2End && leg2End < leg2Start) {
        warnEl.textContent = "Second location end must be on or after its start date.";
        warnEl.classList.add("trip-duration-warning--limit");
        warnEl.removeAttribute("hidden");
        return;
      }
    }

    var leg2StartErr = leg2StartDateError(form);
    if (leg2StartErr) {
      warnEl.textContent = leg2StartErr;
      warnEl.classList.add("trip-duration-warning--limit");
      warnEl.removeAttribute("hidden");
      return;
    }

    var overall = overallTripRange(form);
    if (!overall) {
      warnEl.setAttribute("hidden", "");
      warnEl.textContent = "";
      return;
    }

    var days = tripDurationDays(overall.start, overall.end);
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
    var dateInputs = form.querySelectorAll(
      "[name='query_trip_start_date'], [name='query_trip_end_date'], " +
        "[name='query_trip_end_date_2']"
    );
    if (dateInputs.length === 0) return;

    function onDateChange(ev) {
      var name = ev.target && ev.target.name;
      if (name === "query_trip_end_date" || name === "query_trip_start_date") {
        syncSecondLegStartDate(form);
      }
      updateTripDateConstraints(form);
    }

    dateInputs.forEach(function (el) {
      el.addEventListener("change", onDateChange);
      el.addEventListener("input", onDateChange);
    });
    syncSecondLegStartDate(form);
    updateTripDateConstraints(form);
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

    var loc2El = form.querySelector("[name='query_trip_location_2']");
    var leg2Block = form.querySelector("#trip-leg-second");
    var leg2Visible = leg2Block && !leg2Block.hasAttribute("hidden");
    var leg2Loc = (loc2El && loc2El.value.trim()) || "";
    if (leg2Visible && leg2Loc) {
      var leg2StartStr = (form.querySelector("[name='query_trip_start_date_2']") || {}).value || "";
      var leg2EndStr = (form.querySelector("[name='query_trip_end_date_2']") || {}).value || "";
      if (!leg2StartStr.trim() || !leg2EndStr.trim()) {
        errors.push("Please enter start and end dates for the second location.");
      }
      var leg2Start = parseYmd(leg2StartStr);
      var leg2End = parseYmd(leg2EndStr);
      if (leg2Start && leg2End && leg2End < leg2Start) {
        errors.push("Second location end must be on or after its start date.");
      }
      var leg2StartErr = leg2StartDateError(form);
      if (leg2StartErr) errors.push(leg2StartErr);
    }

    var overall = overallTripRange(form);
    if (overall && overall.end >= overall.start) {
      var maxDays = maxTripDaysFor(form);
      var days = tripDurationDays(overall.start, overall.end);
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

  function tripGenerationStatusUrl() {
    var tripId = document.body.dataset.tripId;
    if (!tripId) return null;
    return "/trips/" + tripId + "/generation_status";
  }

  function stopAgendaReadyPolling() {
    if (pollTimer) {
      clearTimeout(pollTimer);
      pollTimer = null;
    }
  }

  function pollUntilAgendaReady() {
    var url = tripGenerationStatusUrl();
    if (!url) return;

    stopAgendaReadyPolling();
    var polls = 0;
    var maxPolls = 45;
    var pollMs = 4000;

    function poll() {
      polls += 1;
      if (polls > maxPolls) return;

      fetch(url, { credentials: "same-origin", headers: { Accept: "application/json" } })
        .then(function (res) { return res.ok ? res.json() : null; })
        .then(function (data) {
          if (data && data.ready) {
            window.location.reload();
          } else {
            pollTimer = setTimeout(poll, pollMs);
          }
        })
        .catch(function () {
          pollTimer = setTimeout(poll, pollMs);
        });
    }

    pollTimer = setTimeout(poll, pollMs);
  }

  function beginAgendaGeneratingUi() {
    showAgendaLoading();
    pollUntilAgendaReady();
  }

  function hideAgendaLoading() {
    stopAgendaReadyPolling();
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
    beginAgendaGeneratingUi();
  }

  function wireAgendaLoadingForm(formId) {
    var form = document.getElementById(formId);
    if (!form || form.dataset.agendaLoadingWired === "true") return;

    form.dataset.agendaLoadingWired = "true";
    form.addEventListener("submit", handleAgendaFormSubmit);
  }

  function initAgendaGeneratingPage() {
    if (document.body.dataset.agendaGenerating === "true") {
      beginAgendaGeneratingUi();
    }
  }

  function initAgendaLoading() {
    wireAgendaLoadingForm("plan-trip-form");
    wireAgendaLoadingForm("rebuild-agenda-form");
    wireTripDateFields("plan-trip-form");
    wireTripDateFields("rebuild-agenda-form");
    initAgendaGeneratingPage();

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
        beginAgendaGeneratingUi();
      });
    }
  }

  window.syncSecondLegStartDate = syncSecondLegStartDate;

  document.addEventListener("DOMContentLoaded", initAgendaLoading);
  document.addEventListener("turbo:load", initAgendaLoading);
  document.addEventListener("turbo:before-visit", hideAgendaLoading);
  window.addEventListener("pagehide", hideAgendaLoading);
  window.addEventListener("pageshow", function () {
    if (document.body.dataset.agendaGenerating === "true") {
      beginAgendaGeneratingUi();
    } else {
      hideAgendaLoading();
    }
  });
})();
