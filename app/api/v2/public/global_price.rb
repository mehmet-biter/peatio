# encoding: UTF-8
# frozen_string_literal: true

module API
  module V2
    module Public
      class GlobalPrice < Grape::API
        get "/global_price" do
          JSON.parse(Rails.cache.fetch(:global_price) || "{}")
        end
      end
    end
  end
end
