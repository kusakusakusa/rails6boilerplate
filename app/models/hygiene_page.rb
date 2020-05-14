# frozen_string_literal: true

# == Schema Information
#
# Table name: hygiene_pages
#
#  slug       :string(191)      primary key
#  content    :text(65535)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#


class HygienePage < ApplicationRecord
end
