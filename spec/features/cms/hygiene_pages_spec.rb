# frozen_string_literal: true

require 'rails_helper'

feature 'Hygiene Page', js: true do
  let(:admin_user) { create(:admin_user) }
  let(:privacy_policy) { create(:hygiene_page, :privacy_policy) }

  scenario 'should update privacy policy page' do
    sign_in admin_user
    visit edit_cms_hygiene_page_path(privacy_policy.slug)
    append_ckeditor 'hygiene_page_content', with: 'New line'
    click_on 'Save'

    expect(privacy_policy.reload.content).to eq "<h1>Privacy Policy</h1>\r\n\r\n<p>&nbsp;</p>\r\n\r\n<p>New lineLoremIpsum</p>\r\n"
  end
end
