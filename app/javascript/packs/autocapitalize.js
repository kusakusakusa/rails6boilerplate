export default function() {
  $('input.autocapitalize').keyup(function(event) {
    var box = event.target;
    var txt = $(this).val();
    var stringStart = box.selectionStart;
    var stringEnd = box.selectionEnd;
    $(this).val(txt.replace(/^(.)|(\s|\-)(.)/g, function($word) {
      return $word.toUpperCase();
    }));
    box.setSelectionRange(stringStart , stringEnd);
  });

 return this;
}
