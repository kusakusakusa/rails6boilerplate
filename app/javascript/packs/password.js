export const togglePasswordField = function() {
  $('.toggle-password').click(function(e) {
    const passwordField = $(e.target).siblings('input[name*="password"]')
    const passwordType = passwordField.attr('type');
    if (passwordType === 'password') {
      passwordField.attr('type', 'text')
    } else {
      passwordField.attr('type', 'password')
    }
  })
}
