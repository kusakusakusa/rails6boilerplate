json.extract! post, :id, :title, :publish_date :created_at, :updated_at
json.url api_v1_post_url(post, format: :json)
