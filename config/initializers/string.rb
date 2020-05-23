# frozen_string_literal: true

# wrt https://sebastiandobrincu.com/blog/how-to-upload-images-to-rails-api-using-s3

# TODO test

class String
  def split_base64
    return nil if self.blank?

    struct = OpenStruct.new
    if self.match(%r{^data:(.*?);(.*?),(.*)$})
      struct.type = $1 # "image/gif"
      struct.encoder = $2 # "base64"
      struct.data = $3 # data string
      struct.extension = $1.split('/')[1] # "gif"
    else
      struct.type = nil
      struct.encoder = nil
      struct.data = self
      struct.extension = nil
    end

    struct
  end
end
