# frozen_string_literal: true

module WithPdf
  extend ActiveSupport::Concern

  def generate_pdf sample
    html = ActionController::Base.new.render_to_string(
      "layouts/pdf/sample_pdf.html.slim",
      locals: { sample: sample }
    )
    kit = PDFKit.new(
      html,
      page_size: 'A4',
      zoom: Rails.env.development? ? 1 : 0.3,
      footer_html: Rails.root.join("public", "footer.html").to_s,
      footer_line: true,
    )
    kit.stylesheets << Rails.root.join("public", "pdf.css").to_s
    kit.to_pdf
  end
end
