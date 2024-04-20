module Tron
  class Wallet < Peatio::Wallet::Abstract
    include ::Tron::Concerns::Common
    include ::Tron::Concerns::Encryption

    DEFAULT_FEATURES = { skip_deposit_collection: false }.freeze
    DEFAULT_FEE = { fee_limit: 1000000 }

    def initialize(custom_features = {})
      @features = DEFAULT_FEATURES.merge(custom_features).slice(*SUPPORTED_FEATURES)
      @settings = {}
    end

    def configure(settings = {})
      # Clean client state during configure.
      @client = nil

      @settings.merge!(settings.slice(*SUPPORTED_SETTINGS))

      @wallet = @settings.fetch(:wallet) do
        raise Peatio::Wallet::MissingSettingError, :wallet
      end.slice(:uri, :address, :secret)

      @currency = @settings.fetch(:currency) do
        raise Peatio::Wallet::MissingSettingError, :currency
      end.slice(:id, :base_factor, :min_collection_amount, :options)
    end

    def create_address!(options = {})
      client
        .json_rpc(path: 'wallet/generateaddress')
        .yield_self { |pa| { address: pa.fetch('address'), secret: pa.fetch('privateKey') } }
    rescue Tron::Client::Error => exception
      raise Peatio::Wallet::ClientError, exception
    end

    def create_transaction!(transaction, options = {})
      if is_trc10?(@currency)
        create_trc10_transaction!(transaction)
      elsif is_trc20?(@currency)
        create_trc20_transaction!(transaction, options)
      else
        create_coin_transaction!(transaction, options)
      end
    rescue Tron::Client::Error => exception
      raise Peatio::Wallet::ClientError, exception
    end

    def prepare_deposit_collection!(transaction, deposit_spread, deposit_currency)
      # skip deposit_collection in case of trx(coin) deposit.
      return [] if is_coin?(deposit_currency)
      return [] if deposit_spread.blank?

      options = DEFAULT_FEE.merge(deposit_currency.fetch(:options).slice(:fee_limit))

      # We collect fees depending on the number of spread deposit size
      # Example: if deposit spreads on three wallets need to collect eth fee for 3 transactions
      fees = from_base_unit(options.fetch(:fee_limit).to_i, @currency)
      amount = fees * deposit_spread.size

      # If fee amount is greater than min collection amount
      # system will detect fee collection as deposit
      # To prevent this system will raise an error
      min_collection_amount = @currency.fetch(:min_collection_amount).to_d
      if amount > min_collection_amount
        raise Tron::Client::Error, \
              "Fee amount(#{amount}) is greater than min collection amount(#{min_collection_amount})."
      end

      # Collect fees depending on the number of spread deposit size
      # Example: if deposit spreads on three wallets need to collect trx fee for 3 transactions
      transaction.amount = amount
      transaction.options = options

      [create_coin_transaction!(transaction)]
    rescue Tron::Client::Error => e
      raise Peatio::Wallet::ClientError, e
    end

    def load_balance!
      if is_trc10?(@currency)
        load_trc10_balance(@wallet.fetch(:address), @currency)
      elsif is_trc20?(@currency)
        load_trc20_balance(@wallet.fetch(:address), @currency)
      else
        load_coin_balance(@wallet.fetch(:address))
      end.yield_self { |amount| from_base_unit(amount.to_i, @currency) }
    rescue Tron::Client::Error => exception
      raise Peatio::Wallet::ClientError, exception
    end

    private

    def create_trc10_transaction!(transaction, options = {})
      amount = to_base_unit(transaction.amount)

      txid = client
                .json_rpc(
                  path: 'wallet/easytransferassetbyprivate',
                  params: {
                    privateKey: @wallet.fetch(:secret),
                    toAddress: decode_address(transaction.to_address),
                    assetId: asset_id(@currency),
                    amount: amount
                  })
                .dig('transaction', 'txID')
                .yield_self { |txid| reformat_txid(txid) }

      unless txid
        raise Peatio::Wallet::ClientError, \
            "Withdrawal from #{@wallet.fetch(:address)} to #{transaction.to_address} failed."
      end
      transaction.hash = reformat_txid(txid)
      transaction
    end

    def create_trc20_transaction!(transaction, options = {})
      currency_options = @currency.fetch(:options).slice(:trc20_contract_address, :fee_limit)
      options.merge!(DEFAULT_FEE, currency_options)

      amount = to_base_unit(transaction.amount)

      signed_txn = sign_transaction(transaction, amount, options)

      response = client.json_rpc(path: 'wallet/broadcasttransaction', params: signed_txn)

      txid = response.fetch('result', false) ? signed_txn.fetch('txID') : nil

      unless txid
        raise Peatio::Wallet::ClientError, \
            "Withdrawal from #{@wallet.fetch(:address)} to #{transaction.to_address} failed."
      end
      transaction.hash = reformat_txid(txid)
      transaction
    end

    def create_coin_transaction!(transaction, options = {})
      amount = to_base_unit(transaction.amount)
      txid = client
                .json_rpc(path: 'wallet/easytransferbyprivate',
                  params: {
                    privateKey: @wallet.fetch(:secret),
                    toAddress: decode_address(transaction.to_address),
                    amount: amount })
                .dig('transaction', 'txID')
                .yield_self { |txid| reformat_txid(txid) }

      unless txid
        raise Peatio::Wallet::ClientError, \
            "Withdrawal from #{@wallet.fetch(:address)} to #{transaction.to_address} failed."
      end

      transaction.currency_id = 'trx' if transaction.currency_id.blank?
      transaction.amount = from_base_unit(amount, @currency)
      transaction.hash = reformat_txid(txid)
      transaction
    end

    def sign_transaction(transaction, amount, options)
      client
        .json_rpc(path: 'wallet/gettransactionsign',
          params: {
            transaction: trigger_smart_contract(transaction, amount, options),
            privateKey: @wallet.fetch(:secret) }
        )
    end

    def trigger_smart_contract(transaction, amount, options)
      client
        .json_rpc(path: 'wallet/triggersmartcontract',
          params: {
            contract_address: decode_address(options.fetch(:trc20_contract_address)),
            function_selector: 'transfer(address,uint256)',
            parameter: abi_encode(decode_address(transaction.to_address)[2..42], amount.to_s(16)),
            fee_limit: options.fetch(:fee_limit),
            owner_address: decode_address(@wallet.fetch(:address)) })
        .fetch('transaction')
    end

    def to_base_unit(value)
      x = value.to_d * @currency.fetch(:base_factor)
      unless (x % 1).zero?
        raise Peatio::Wallet::ClientError,
              "Failed to convert value to base (smallest) unit because it exceeds the maximum precision: " \
          "#{value.to_d} - #{x.to_d} must be equal to zero."
      end
      x.to_i
    end

    def client
      @client ||= Client.new(get_settings(:uri))
    end

    def get_settings(key)
      @wallet.fetch(key) { raise Peatio::Wallet::MissingSettingError, key.to_s }
    end
  end
end
