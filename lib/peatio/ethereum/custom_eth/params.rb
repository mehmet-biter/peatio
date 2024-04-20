module Ethereum::CustomEth
  module Params
    def native_currency_id
      'custom_eth'
    end

    def coin_type
      'custom_eth'
    end

    def token_name
      'custom_erc20'
    end
  end
end
