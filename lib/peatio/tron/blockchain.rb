module Tron
  class Blockchain < Peatio::Blockchain::Abstract
    include ::Tron::Concerns::Common
    include ::Tron::Concerns::Encryption

    NATIVE_CURRENCY_ID = 'trx'
    DEFAULT_FEATURES = { case_sensitive: true, cash_addr_format: false }.freeze
    TRC20_EVENT_IDENTIFIER = 'ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef'
    SUCCESS = 'success'
    FAILED = 'failed'
    EVENT_IDENTIFIERS = %w[TransferContract TransferAssetContract]

    def initialize(custom_features = {})
      @features = DEFAULT_FEATURES.merge(custom_features).slice(*SUPPORTED_FEATURES)
      @settings = {}
    end

    def configure(settings = {})
      # Clean client state during configure.
      @client = nil

      @trc10 = []; @trc20 = []; @trx = []

      @settings.merge!(settings.slice(*SUPPORTED_SETTINGS))
      @settings[:currencies]&.each do |currency|
        if is_trc10?(currency)
          @trc10 << currency
        elsif is_trc20?(currency)
          @trc20 << currency
        else
          @trx << currency
        end
      end
    end

    def fetch_block!(block_number)
      client
        .json_rpc(path: 'wallet/getblockbynum', params: { num: block_number })
        .fetch('transactions', [])
        .each_with_object([]) do |tx, txns|
          if EVENT_IDENTIFIERS.include? tx.dig('raw_data', 'contract')[0].fetch('type', nil)
            next if invalid_txn?(tx)
          else
            # fetch trc20 txn info logs
            tx = client.json_rpc(path: 'wallet/gettransactioninfobyid', params: { value: tx['txID'] })
            next if tx.nil? || invalid_trc20_txn?(tx)
          end

          txn = build_txn(tx.merge('block_number' => block_number)).map do |txn|
            Peatio::Transaction.new(txn)
          end

          txns.append(*txn)
        end.yield_self { |txns| Peatio::Block.new(block_number, txns) }
    rescue Client::Error => e
      raise Peatio::Blockchain::ClientError, e
    end

    def latest_block_number
      client
        .json_rpc(path: 'wallet/getblockbylatestnum', params: { num: 1 })
        .fetch('block')[0]['block_header']['raw_data']['number']
    rescue Client::Error => e
      raise Peatio::Blockchain::ClientError, e
    end

    def load_balance_of_address!(address, currency_id)
      currency = @settings[:currencies].find { |c| c[:id] == currency_id.to_s }

      raise UndefinedCurrencyError unless currency

      if is_trc10?(currency)
        load_trc10_balance(address, currency)
      elsif is_trc20?(currency)
        load_trc20_balance(address, currency)
      else
        client
          .json_rpc(path: 'wallet/getaccount', params: { address: decode_address(address) })
          .fetch('balance', 0)
      end.yield_self { |amount| from_base_unit(amount.to_i, currency) }
    rescue Client::Error => e
      raise Peatio::Blockchain::ClientError, e
    end

    private

    def build_txn(transaction)
      if transaction.has_key?('contract_address')
        build_trc20_txn(transaction)
      else
        case transaction['raw_data']['contract'][0]['type']
        when 'TransferContract'
          build_coin_txn(transaction)
        when 'TransferAssetContract'
          build_trc10_txn(transaction)
        end
      end
    end

    def build_trc10_txn(txn)
      tx = txn['raw_data']['contract'][0]
      currencies = @trc10.select do |currency|
        asset_id(currency) == decode_hex(tx['parameter']['value']['asset_name'])
      end

      currencies.each_with_object([]) do |currency, formatted_txs|
        formatted_txs << { hash: reformat_txid(txn['txID']),
                           amount: from_base_unit(tx['parameter']['value']['amount'], currency),
                           to_address: encode_address(tx['parameter']['value']['to_address']),
                           txout: 0,
                           block_number: txn['block_number'],
                           currency_id: currency.fetch(:id),
                           fee_currency_id: NATIVE_CURRENCY_ID,
                           status: SUCCESS }
      end
    end

    def build_trc20_txn(txn_receipt)
      if trc20_txn_status(txn_receipt) == FAILED && txn_receipt.fetch('log', []).blank?
        return build_invalid_trc20_txn(txn_receipt)
      end

      formatted_txs = []
      txn_receipt.fetch('log', []).each_with_index do |log, index|
        next if log.fetch('topics', []).blank? || log.fetch('topics')[0] != TRC20_EVENT_IDENTIFIER

        currencies = @trc20.select do |currency|
          contract_address(currency) == encode_address("41#{log.fetch('address')}")
        end
        next if currencies.blank?

        destination_address = encode_address("41#{log.fetch('topics').last[-40..-1]}")

        currencies.each do |currency|
          formatted_txs << { hash: reformat_txid(txn_receipt.fetch('id')),
                             amount: from_base_unit(log.fetch('data').hex, currency),
                             to_address: destination_address,
                             txout: index,
                             block_number: txn_receipt['block_number'],
                             currency_id: currency.fetch(:id),
                             fee_currency_id: NATIVE_CURRENCY_ID,
                             status: trc20_txn_status(txn_receipt)
          }
        end
      end
      formatted_txs
    end

    def build_coin_txn(txn_hash)
      txn = txn_hash['raw_data']['contract'][0]
      @trx.map do |currency|
        { hash: reformat_txid(txn_hash['txID']),
          amount: from_base_unit(txn['parameter']['value']['amount'], currency),
          to_address: encode_address(txn['parameter']['value']['to_address']),
          txout: 0,
          block_number: txn_hash['block_number'],
          currency_id: currency.fetch(:id),
          fee_currency_id: NATIVE_CURRENCY_ID,
          status: SUCCESS }
      end
    end

    def build_invalid_trc20_txn(txn_receipt)
      currencies = @trc20.select do |currency|
        contract_address(currency) == encode_address(txn_receipt.fetch('contract_address'))
      end

      return [] if currencies.blank?

      currencies.each_with_object([]) do |currency, invalid_txns|
        invalid_txns << { hash: reformat_txid(txn_receipt.fetch('txID')),
                         block_number: txn_receipt.fetch('block_number'),
                         currency_id: currency.fetch(:id),
                         status: trc20_txn_status(txn_receipt) }
      end
    end

    def trc20_txn_status(txn_hash)
      txn_hash['receipt']['result'] == 'SUCCESS' ? SUCCESS : FAILED
    end

    def invalid_txn?(tx)
      tx['raw_data']['contract'][0]['parameter']['value']['amount'].to_i == 0 \
         || tx['ret'][0]['contractRet'] == 'REVERT'
    end

    def invalid_trc20_txn?(txn)
      txn.fetch('contract_address', '').blank? || txn.fetch('log', []).blank?
    end

    def client
      @client ||= Client.new(get_settings(:server))
    end

    def get_settings(key)
      @settings.fetch(key) { raise Peatio::Blockchain::MissingSettingError, key.to_s }
    end
  end
end
