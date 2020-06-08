# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'String', type: :request do
  feature '#split_base64' do
    scenario 'should return nil if string is blank' do
      expect("".split_base64).to eq nil
    end

    scenario 'should have nil extension if string does not have data' do
      expect(image_no_extension_base64.split_base64.extension).to eq nil
      expect(SecureRandom.hex.split_base64.extension).to eq nil
    end

    scenario 'should have extension even if string is url unsafe' do
      expect(image_unsafe_base64.split_base64.extension).to eq 'jpeg'
    end

    scenario 'should have extension if string have data' do
      expect(image_base64.split_base64.extension).to eq 'jpeg'
      expect(video_base64.split_base64.extension).to eq 'mp4'
    end
  end
end
