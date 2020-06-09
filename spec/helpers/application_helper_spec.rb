# frozen_string_literal: true

require "rails_helper"

RSpec.describe ApplicationHelper do
  feature '#display_date' do
    scenario 'should return "-" if date is nil' do
      expect(helper.display_date(nil)).to eq '-'
    end

    scenario 'should return date in format' do
      expect(helper.display_date(Date.parse('2020-12-31'))).to eq "Dec 31, 2020"
    end
  end
end
