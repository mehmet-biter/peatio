require 'openssl'
require 'jwt-multisig'
require 'base64'
require 'json'

def generate_jwt_management(data)
  jwt = JWT::Multisig.generate_jwt(
    { data: data, exp:  Time.now.to_i + 60, },
    {
      :peatio => OpenSSL::PKey.read(Base64.urlsafe_decode64(ENV.fetch('JWT_PRIVATE_KEY')))
    },
    {
      :peatio => 'RS256'
    }
  )

  JSON.dump(jwt)
end
