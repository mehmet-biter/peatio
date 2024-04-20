module Tron
  module Concerns
    module Common
      extend ActiveSupport::Concern
    
      private
    
      def is_trc20?(currency)
        currency.dig(:options, :trc20_contract_address).present?
      end
    
      def is_trc10?(currency)
        currency.dig(:options, :trc10_asset_id).present?
      end
    
      def is_coin?(currency)
        currency.dig(:options, :trc20_contract_address).blank?
      end
    
      def contract_address(currency)
        currency.dig(:options, :trc20_contract_address)
      end
    
      def asset_id(currency)
        currency.dig(:options, :trc10_asset_id)
      end
    
      def from_base_unit(value, currency)
        value.to_d / currency.fetch(:base_factor).to_d
      end
    
      def load_coin_balance(address)
        client
          .json_rpc(path: 'wallet/getaccount', params: { address: decode_address(address) })
          .fetch('balance', 0)
      end
    
      def load_trc10_balance(address, currency)
        client
          .json_rpc(path: 'wallet/getaccount', params: { address: decode_address(address) })
          .fetch('assetV2', [])
          .find { |asset| asset['key'] == asset_id(currency) }
          .try(:fetch, 'value', 0)
      end
    
      def load_trc20_balance(address, currency)
        client
          .json_rpc(
            path: 'wallet/triggersmartcontract',
            params: {
              owner_address: decode_address(address),
              contract_address: decode_address(contract_address(currency)),
              function_selector: 'balanceOf(address)',
              parameter: abi_encode(decode_address(address)[2..42]) })
          .fetch('constant_result')[0]
          .hex
      end

    end  
  end
end
