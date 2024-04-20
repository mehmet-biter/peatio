require 'json'
require 'faraday'

def http_client(url)
  Faraday.new(url: url) do |conn|
    conn.request :json
    conn.response :json
    conn.adapter Faraday.default_adapter
  end
end

# Example
# http_client('http://barong:8001/api/v2/management')
#   .public_send(:post, '/phones/send', generate_jwt_management({ :uid => 'UID123', :content => 'Hello World'}))
#   .body
