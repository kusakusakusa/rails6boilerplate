json.response_code @response_code
json.response_message @response_message
if @response_code == 'custom.success.default'
  json.user do
    json.merge! @current_user.json_attributes
  end
end
