# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  layout 'mailer'

  def sample_pdf sample
    mail(
      subject: 'Sample PDF',
      to: 'sample@mailinator.com',
      from: 'sample@mailinator.com',
    ) do |format|
      format.html
      format.pdf do
        attachments['sample.pdf'] = WickedPdf.new.pdf_from_string(
          render_to_string(
            pdf: "sample_pdf", # Excluding ".pdf" extension.
            template: "layouts/pdf/sample_pdf.html.slim",
            layout: false,
            locals: { sample: sample },
            footer:  {
              html: { 
                template: 'layouts/pdf/footer.html.slim',
                layout: false,
                locals: { sample: sample }
              }
            },
            margin:  {   
              top: 10,
              bottom: 40,
              left: 10,
              right: 10
            }
          )
        )
      end
    end
  end
end
