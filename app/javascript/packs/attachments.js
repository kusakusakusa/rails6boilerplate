require('jquery-ui');
require("venobox");
require("venobox/venobox/venobox.min.css");
require("plyr");
require("plyr/dist/plyr.css");

import Plyr from 'plyr';

document.addEventListener("turbolinks:load", () => {
  $("#sortable").sortable({
    stop: function( event, ui ) {
      const ordering = $('.attachment-id').map(function(_, el) { return $(el).text() });
      $('#ordering').val(ordering.toArray().join(','));
    }
  });

  $('.venobox').venobox({
    share: []
  });

  const player = Plyr.setup('.video');
});
