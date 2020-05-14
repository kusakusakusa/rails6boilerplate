# == Schema Information
#
# Table name: hygiene_pages
#
#  slug       :string(191)      primary key
#  content    :text(65535)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

require 'rails_helper'

RSpec.describe HygienePage, type: :model do
end
