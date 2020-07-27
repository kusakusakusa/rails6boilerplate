require("dropzone/dist/basic.css");
require("dropzone/dist/dropzone.css");

import Dropzone from 'dropzone'

Dropzone.options.massUploads = {
  paramName: 'attachment[file]',
  maxFilesize: 100
}
