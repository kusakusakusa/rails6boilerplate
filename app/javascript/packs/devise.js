// This file is automatically compiled by Webpack, along with any other files
// present in this directory. You're encouraged to place your actual application logic in
// a relevant structure within app/javascript and only use these pack files to reference
// that code so it'll be compiled.

require("@rails/ujs").start()
require("turbolinks").start()
require("@rails/activestorage").start()
require("channels")
require("jquery")
require("bootstrap")
require("jquery.easing")

// custom
require("../scss/sb-admin-2/sb-admin-2.scss")
require("../scss/floating-labels.sass")
require("../scss/fontawesome.scss")
require("../scss/fields.sass")

// Uncomment to copy all static images under ../images to the output folder and reference
// them with the image_pack_tag helper in views (e.g <%= image_pack_tag 'rails.png' %>)
// or the `imagePath` JavaScript helper below.
//
// const images = require.context('../images', true)
// const imagePath = (name) => images(name, true)

import { togglePasswordField } from './password.js';
import autocapitalize from './autocapitalize.js';

document.addEventListener("turbolinks:load", () => {
  window.scrollTo(0, 0);

  togglePasswordField();
  autocapitalize();
});
