// Loading overlay for AI agenda generation (estimated progress — server has no real %).
(function () {
  var progressTimer = null;
  var ESTIMATED_MS = 75000;

  function showAgendaLoading() {
    var overlay = document.getElementById("agenda-loading-overlay");
    if (!overlay) return;

    overlay.removeAttribute("hidden");
    overlay.setAttribute("aria-hidden", "false");

    var percentEl = document.getElementById("agenda-loading-percent");
    var surferMover = document.getElementById("agenda-surfer-mover");
    if (!percentEl) return;

    if (progressTimer) clearInterval(progressTimer);

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

  function wireAgendaLoadingForm(formId) {
    var form = document.getElementById(formId);
    if (!form || form.dataset.agendaLoadingWired === "true") return;

    form.dataset.agendaLoadingWired = "true";
    form.addEventListener("submit", showAgendaLoading);
  }

  function initAgendaLoading() {
    wireAgendaLoadingForm("plan-trip-form");
    wireAgendaLoadingForm("rebuild-agenda-form");

    if (!window.__agendaLoadingTurboSubmit) {
      window.__agendaLoadingTurboSubmit = true;
      document.addEventListener("turbo:submit-start", function (ev) {
        var el = ev.detail && ev.detail.formSubmission && ev.detail.formSubmission.formElement;
        if (!el) return;
        if (el.id === "plan-trip-form" || el.id === "rebuild-agenda-form") {
          showAgendaLoading();
        }
      });
    }
  }

  document.addEventListener("DOMContentLoaded", initAgendaLoading);
  document.addEventListener("turbo:load", initAgendaLoading);
})();
