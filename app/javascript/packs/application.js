// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.

require("@rails/ujs").start()
require("turbolinks").start()
require("@rails/activestorage").start()
require("channels")
require("jquery")
require("chart.js")
require("bootstrap")
require("jquery.easing")

// custom
require("../scss/sb-admin-2/sb-admin-2.scss")
require("../scss/fields.sass")
require("../scss/fontawesome.scss")

// Uncomment to copy all static images under ../images to the output folder and reference
// them with the image_pack_tag helper in views (e.g <%= image_pack_tag 'rails.png' %>)
// or the `imagePath` JavaScript helper below.
//
// const images = require.context('../images', true)
// const imagePath = (name) => images(name, true)

import flatpickr from "flatpickr"
require("flatpickr/dist/flatpickr.css")

document.addEventListener("turbolinks:load", () => {
  flatpickr("[data-behavior='flatpickr']", {
    altInput: true,
    altFormat: 'F j, Y',
    dateFormat: 'Y-m-d'
  });

  $('.image-input').on('change', function() {
    const element = this;
    if (element.files && element.files[0]) {
      const reader = new FileReader();

      reader.onload = function(e) {
        element.previousSibling.src = e.target.result
      }
      
      reader.readAsDataURL(element.files[0]);
    }
  });

  $('.image-delete').on('click', function() {
    $("input[name='" + $(this).data('field-name') + "']").val('')
    $(".image-input-preview[data-field-name='" + $(this).data('field-name') + "']").prop('src', '')
  });
});
