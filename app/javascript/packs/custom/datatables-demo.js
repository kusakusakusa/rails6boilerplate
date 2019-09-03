require("datatables.net")
require('datatables.net-bs4')
require("datatables.net-bs4/css/dataTables.bootstrap4.min.css")

document.addEventListener("turbolinks:load", () => {
  $('.dataTable').DataTable();
});
