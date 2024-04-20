require 'uri'
require 'net/http'

module Jobs
  module Cron
    class GlobalPrice
      def self.process
        uri = URI('https://min-api.cryptocompare.com/data/pricemulti?fsyms=USD,USDT&tsyms=USD,USDT,EUR,VND,CNY,JPY')
        res = Net::HTTP.get_response(uri)
        Rails.cache.write(:global_price, res.body) if res.is_a?(Net::HTTPSuccess)

        sleep 600
      end
    end
  end
end
