// Toggle second location leg + Google Places autocomplete on both inputs.
(function () {
  function initTripLocationLegs() {
    document.querySelectorAll("form[data-max-trip-days]").forEach(function (form) {
      if (form.dataset.tripLegsWired === "true") return;
      form.dataset.tripLegsWired = "true";

      var addBtn = form.querySelector("#trip-add-second-location-btn");
      var removeBtn = form.querySelector("#trip-remove-second-location-btn");
      var leg2 = form.querySelector("#trip-leg-second");
      if (!addBtn || !leg2) return;

      function showLeg2() {
        leg2.removeAttribute("hidden");
        addBtn.setAttribute("hidden", "");
        if (window.syncSecondLegStartDate) window.syncSecondLegStartDate(form);
        if (window.initTripLocationAutocomplete) window.initTripLocationAutocomplete();
      }

      function hideLeg2() {
        leg2.setAttribute("hidden", "");
        addBtn.removeAttribute("hidden");
        leg2.querySelectorAll("input").forEach(function (input) {
          input.value = "";
        });
      }

      addBtn.addEventListener("click", showLeg2);
      if (removeBtn) {
        removeBtn.addEventListener("click", hideLeg2);
      }
    });

    if (window.initTripLocationAutocomplete) window.initTripLocationAutocomplete();
  }

  document.addEventListener("DOMContentLoaded", initTripLocationLegs);
  document.addEventListener("turbo:load", initTripLocationLegs);
})();
