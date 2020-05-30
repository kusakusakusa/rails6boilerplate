# frozen_string_literal: true

require 'rails_helper'

feature 'Attachment', js: true do
  let!(:admin_user) { create(:admin_user) }
  let!(:user) { create(:user) }

  [
    {
      record: 'sample',
      attachment: 'image'
    },
    {
      record: 'sample',
      attachment: 'video'
    },
    {
      record: 'sample',
      attachment: 'audio'
    }
  ].each do |setting|
    let!(setting[:record].to_sym) { create(setting[:record].to_sym) }

    feature setting[:record] do
      before :each do
        @record = setting[:record]
        @attachment = setting[:attachment]
      end

      scenario 'should not allow user to enter' do
        sign_in user
        visit "/cms/#{@record.pluralize}/#{public_send(@record).id}/#{@attachment.pluralize}"
        expect(page).to have_current_path('/')
        expect(page).to have_content("You are not authorized to visit this page.")
      end

      scenario 'should show record name' do
        sign_in admin_user
        visit "/cms/#{@record.pluralize}/#{public_send(@record).id}/#{@attachment.pluralize}"
        expect(page).to have_content "#{@record.titlecase} #{public_send(@record).id} #{@attachment.pluralize.titlecase}"
      end

      scenario 'should show all attachments belonging to record' do
        sign_in admin_user
        visit "/cms/#{@record.pluralize}/#{public_send(@record).id}/#{@attachment.pluralize}"
        expect(find_all(:css, '.attachment-container').count).to eq 2
        expect(find_all(:css, '.attachment-id').count).to eq 2
        attachment_ids = find_all(:css, '.attachment-id').map(&:text)
        expect(public_send(@record).public_send(@attachment.pluralize).where(id: attachment_ids).count).to eq 2
      end

      feature 'create' do
        before :each do
          sign_in admin_user
          expect(public_send(@record).public_send(@attachment.pluralize).count).to eq 2
          visit "/cms/#{@record.pluralize}/#{public_send(@record).id}/#{@attachment.pluralize}/new"
        end

        scenario 'should create new attachment' do
          public_send("attach_#{@attachment}_file", 'attachment[file]')
          
          click_on "Create #{@attachment.titlecase}"
          expect(page).to have_content "#{@attachment.capitalize} successfully added"
          expect(page).to have_current_path "/cms/#{@record.pluralize}/#{public_send(@record).id}/#{@attachment.pluralize}"
          expect(find_all(:css, '.attachment-container').count).to eq 3
          expect(public_send(@record).public_send(@attachment.pluralize).count).to eq 3
        end

        scenario 'should return error and not create attachment on invalid content type' do
          attach_ruby_file 'attachment[file]'
          click_on "Create #{@attachment.titlecase}"

          expect(page).to have_current_path "/cms/#{@record.pluralize}/#{public_send(@record).id}/#{@attachment.pluralize}/new"
          expect(page).to have_content "Validation failed: #{@attachment.pluralize.humanize} has an invalid content type"
          expect(public_send(@record).reload.public_send(@attachment.pluralize).count).to eq 2
        end
      end

      feature 'edit' do
        before :each do
          sign_in admin_user
        end

        scenario 'should edit attachment' do
          expect(public_send(@record).public_send(@attachment.pluralize).count).to eq 2
          initial_attachment_ids = public_send(@record).public_send(@attachment.pluralize).pluck(:id)

          visit "/cms/#{@record.pluralize}/#{public_send(@record).id}/#{@attachment.pluralize}/#{initial_attachment_ids.first}/edit"
          public_send("attach_#{@attachment}_file", 'attachment[file]')
          click_on "Update #{@attachment.titlecase}"

          expect(page).to have_content "#{@attachment.capitalize} successfully updated"
          expect(public_send(@record).reload.public_send(@attachment.pluralize).count).to eq 2
          new_attachment_ids = public_send(@record).public_send(@attachment.pluralize).pluck(:id)
          expect(new_attachment_ids.count).to eq initial_attachment_ids.count
          expect((new_attachment_ids - initial_attachment_ids).empty?).not_to eq true
        end

        scenario 'should purge attachment' do
          initial_attachment_count = ActiveStorage::Attachment.count
          visit "/cms/#{@record.pluralize}/#{public_send(@record).id}/#{@attachment.pluralize}/#{public_send(@record).public_send(@attachment.pluralize).first.id}/edit"
          public_send("attach_#{@attachment}_file", 'attachment[file]')
          click_on "Update #{@attachment.titlecase}"
          expect(ActiveStorage::Attachment.count - initial_attachment_count).to eq 0
        end

        scenario 'should return error and not edit attachment on invalid content type' do
          expect(public_send(@record).public_send(@attachment.pluralize).count).to eq 2
          initial_attachment_ids = public_send(@record).public_send(@attachment.pluralize).pluck(:id)

          visit "/cms/#{@record.pluralize}/#{public_send(@record).id}/#{@attachment.pluralize}/#{initial_attachment_ids.first}/edit"
          attach_ruby_file 'attachment[file]'
          click_on "Update #{@attachment.titlecase}"

          expect(page).to have_current_path "/cms/#{@record.pluralize}/#{public_send(@record).id}/#{@attachment.pluralize}/#{initial_attachment_ids.first}/edit"
          expect(page).to have_content "Validation failed: #{@attachment.pluralize.humanize} has an invalid content type"
          expect(public_send(@record).reload.public_send(@attachment.pluralize).count).to eq 2
          expect((public_send(@record).reload.public_send(@attachment.pluralize).pluck(:id) - initial_attachment_ids).empty?).to eq true
        end
      end

      if Rails.application.routes.url_helpers.method_defined? "update_order_cms_#{setting[:record]}_#{setting[:attachment].pluralize}_path"
        feature 'ordering' do
          scenario 'should update ordering of attachments' do
            sign_in admin_user
            visit "/cms/#{@record.pluralize}/#{public_send(@record).id}/#{@attachment.pluralize}"
            intial_attachment_order = find_all(:css, '.attachment-id').map(&:text)
            expect(find(:css, 'input#ordering', visible: false).value).to eq intial_attachment_order.join(',')

            buffer_height = 20
            height_of_attachment_container = find_all(:css, '.attachment-container').first.style(:height)['height'].gsub('px', '').to_i
            find_all(:css, '.attachment-container').first.drag_by(0, height_of_attachment_container + buffer_height)
            expect(find_all(:css, '.attachment-id').map(&:text)).to eq intial_attachment_order.reverse
            expect(find(:css, 'input#ordering', visible: false).value).to eq intial_attachment_order.reverse.join(',')

            click_on 'Update Order'
            expect(page).to have_content 'Order successfully updated'
            expect(find_all(:css, '.attachment-id').map(&:text)).to eq intial_attachment_order.reverse
          end
        end
      end
    end
  end
end
