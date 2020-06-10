require("datatables.net")
require('datatables.net-bs4')
require('datatables.net-plugins/sorting/natural')
require("datatables.net-bs4/css/dataTables.bootstrap4.min.css")

const dataTables = [];

document.addEventListener("turbolinks:load", () => {
  if (dataTables.length === 0 && $('.data-table').length !== 0) {
    $('.data-table').each((_, element) => {
      dataTables.push($(element).DataTable({
        pageLength: 50,
        columnDefs: [
          { type: 'natural-nohtml', targets: '_all' }
        ]
      }));
    });
  }
});

document.addEventListener("turbolinks:before-cache", () => {
  while (dataTables.length !== 0) {
    dataTables.pop().destroy();
  }
});
