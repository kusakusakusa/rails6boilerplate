class ExperimentEmailsJob < ApplicationJob
  queue_as :default

  def perform sample_id
    sample = Sample.find(sample_id)
    ApplicationMailer.send_emails(sample).deliver_now
  end
end
