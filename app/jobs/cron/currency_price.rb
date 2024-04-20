module Jobs
  module Cron
    class CurrencyPrice
      class <<self
        def process
          Currency.coins.active.find_each do |currency|
            currency.update_price
          rescue StandardError => e
            report_exception_to_screen(e)
            next
          end

          sleep Peatio::App.config.currency_price_fetch_period_time
        end
      end
    end
  end
end
