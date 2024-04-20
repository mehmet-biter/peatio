require 'digest/sha3'

module Tron
  module Concerns
    module Encryption
      extend ActiveSupport::Concern
      
      ALGO = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
      
      def decode_address(address)
        base58_to_bin(address)
      end

      def encode_address(hex_addr)
        sha256_addr = sha256_encode(sha256_encode(hex_addr))[0, 8]
        (hex_addr + sha256_addr).hex.digits(58).reverse.map {|i| ALGO[i]}.join
      end

      def reformat_txid(txid)
        txid
      end

      def decode_hex(hex_addr)
        [hex_addr].pack('H*')
      end

      def encode_hex(str)
        str.unpack('H*')[0]
      end

      def abi_encode(*args)
        args.each_with_object('') do |arg, data|
          data.concat(arg.gsub(/\A0x/, '').rjust(64, '0'))
        end
      end
      
      private

      def sha256_encode(hex_addr)
        Digest::SHA256.hexdigest([hex_addr].pack('H*'))
      end

      def base58_to_int(base58_val)
        int_val = 0
        base58_val.reverse.split(//).each_with_index do |char, index|
          int_val += (ALGO.index(char)) * (ALGO.length ** (index))
        end
        int_val
      end

      def base58_to_bin(base58_val)
        int_to_hex(base58_to_int(base58_val))[0, 42]
      end

      def int_to_hex(int_val)
        hex = int_val.to_s(16)
        (hex.length % 2 == 0) ? hex : ('0' + hex)
      end
    end
  end
end
