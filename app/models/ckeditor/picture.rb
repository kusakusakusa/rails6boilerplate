# frozen_string_literal: true

# == Schema Information
#
# Table name: ckeditor_assets
#
#  id                :bigint           not null, primary key
#  data_file_name    :string(255)      not null
#  data_content_type :string(255)
#  data_file_size    :integer
#  data_fingerprint  :string(255)
#  type              :string(30)
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#


class Ckeditor::Picture < Ckeditor::Asset
  # you may need this wrt https://github.com/galetahub/ckeditor/issues/739
  # self.inheritance_column = nil

  # for validation, see https://github.com/igorkasyanchuk/active_storage_validations

  def url_content
    # variants causing Aws::Waiters::Errors::UnexpectedError
    # not going to show variant
    # rails_representation_url(storage_data.variant(resize: '800>').processed, only_path: true)
    rails_blob_path(storage_data, only_path: true)
  end

  def url_thumb
    # variants causing Aws::Waiters::Errors::UnexpectedError
    # not going to show variant
    # rails_representation_url(storage_data.variant(resize: '118x100').processed, only_path: true)
    rails_blob_path(storage_data, only_path: true)
  end
end
