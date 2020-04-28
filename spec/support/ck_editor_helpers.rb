# frozen_string_literal: true

module CkEditorHelpers
  def append_ckeditor id, with:
    within_frame find("#cke_#{id} iframe") do
      find('body').base.click
      find('body').send_keys :enter
      find('body').base.send_keys with
    end
  end
end
