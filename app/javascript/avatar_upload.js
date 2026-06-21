// Convert iPhone HEIC/HEIF picks to JPEG before upload (desktop browsers can't display HEIC).
(function () {
  function isHeic(file) {
    if (!file) return false;
    var type = (file.type || "").toLowerCase();
    if (type === "image/heic" || type === "image/heif") return true;
    return /\.heic$/i.test(file.name || "");
  }

  function wireAvatarInput(input) {
    if (!input || input.dataset.avatarUploadWired === "true") return;
    input.dataset.avatarUploadWired = "true";

    input.addEventListener("change", function () {
      var file = input.files && input.files[0];
      if (!file || !isHeic(file)) return;

      var form = input.form;
      if (!form) return;

      var status = form.querySelector("[data-avatar-convert-status]");
      if (status) {
        status.removeAttribute("hidden");
        status.textContent = "Converting iPhone photo to JPEG…";
      }

      import("heic2any")
        .then(function (mod) {
          var heic2any = mod.default || mod;
          return heic2any({ blob: file, toType: "image/jpeg", quality: 0.92 });
        })
        .then(function (converted) {
          var blob = Array.isArray(converted) ? converted[0] : converted;
          var jpeg = new File([blob], "profile-photo.jpg", { type: "image/jpeg" });
          var list = new DataTransfer();
          list.items.add(jpeg);
          input.files = list.files;
          if (status) status.textContent = "Photo ready (saved as JPEG).";
        })
        .catch(function () {
          if (status) {
            status.textContent =
              "Could not convert this photo. In iPhone Settings → Camera → Formats, choose “Most Compatible”, then pick the photo again.";
          }
        });
    });
  }

  function initAvatarUpload() {
    document.querySelectorAll("input[type='file'][name='user[avatar]']").forEach(wireAvatarInput);
  }

  document.addEventListener("DOMContentLoaded", initAvatarUpload);
  document.addEventListener("turbo:load", initAvatarUpload);
})();
