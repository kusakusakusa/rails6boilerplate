# frozen_string_literal: true

require 'rails_helper'

feature 'Samples', js: true do
  let!(:admin_user) { create(:admin_user) }
  let!(:user) { create(:user) }
  let!(:sample) { create(:sample) }

  [
    '/cms/samples',
    "/cms/samples/_sample_id_",
    "/cms/samples/_sample_id_/edit"
  ].each do |route|
    before :each do
      sign_in admin_user
    end

    scenario 'should not allow user to enter' do
      sign_in user
      visit route.gsub('_sample_id_', sample.id.to_s)
      expect(page).to have_current_path('/')
      expect(page).to have_content("You are not authorized to visit this page.")
    end

    if route == '/cms/samples'
      scenario 'should show all samples' do
        sign_in admin_user
        create(:sample)
        visit '/cms/samples'
        expect(find_all(:css, 'tbody tr').count).to eq 2
      end
    else
      scenario 'should show correct sample' do
        another_sample = create(:sample)
        visit route.gsub('_sample_id_', another_sample.id.to_s)
        expect(page).to have_content(another_sample.title)
        expect(page).not_to have_content(sample.title)
      end
    end
  end

  feature 'update' do
    before :each do
      sign_in admin_user
      visit "/cms/samples/#{sample.id}/edit"
    end

    scenario 'should update attributes of sample' do
      fill_in 'sample[title]', with: 'New Title'
      fill_in 'sample[description]', with: 'This is new sample description'
      find('#label_sample_featured_true').click
      set_date '#sample_publish_date', '2020-01-01'
      fill_in 'sample[price]', with: '1000'
      click_on 'Update Sample'

      sample.reload
      expect(page).to have_content('Sample successfully updated')
      expect(page).to have_current_path("/cms/samples/#{sample.id}")
      expect(sample.title).to eq 'New Title'
      expect(sample.description).to eq 'This is new sample description'
      expect(sample.featured).to eq true
      expect(sample.publish_date).to eq Date.parse('2020-01-01')
      expect(sample.price).to eq 1000
      expect(sample.featured_image.attached?).to eq true
    end

    scenario 'should not make sample feature image nil if sample image is not updated' do
      expect(sample.featured_image.attached?).to eq true
      click_on 'Update Sample'
      expect(sample.reload.featured_image.attached?).to eq true
    end

    scenario 'should change sample featured image if new file is uploaded' do
      original_featured_image_blob_id = sample.featured_image.attachment.blob_id
      attach_file('sample[featured_image]', File.join(Rails.root, 'spec', 'support', 'sample.jpg'), visible: false)
      click_on 'Update Sample'
      expect(page).to have_content('Sample successfully updated')
      expect(sample.reload.featured_image.attachment.blob_id).not_to eq original_featured_image_blob_id
    end
  end

  feature 'create' do
    before :each do
      sign_in admin_user
      visit "/cms/samples/new"
    end

    scenario 'should create new sample' do
      expect(Sample.count).to eq 1
      fill_in 'sample[title]', with: 'New Title'
      fill_in 'sample[description]', with: 'This is new sample description'
      find('#label_sample_featured_true').click
      set_date '#sample_publish_date', '2020-01-01'
      fill_in 'sample[price]', with: '1000'
      attach_file('sample[featured_image]', File.join(Rails.root, 'spec', 'support', 'sample.jpg'), visible: false)
      click_on 'Create Sample'

      expect(Sample.count).to eq 2
      sample = Sample.last
      expect(page).to have_content('Sample successfully created')
      expect(page).to have_current_path("/cms/samples/#{sample.id}")
      expect(sample.title).to eq 'New Title'
      expect(sample.description).to eq 'This is new sample description'
      expect(sample.featured).to eq true
      expect(sample.publish_date).to eq Date.parse('2020-01-01')
      expect(sample.price).to eq 1000
      expect(sample.featured_image.attached?).to eq true
    end
  end
end
