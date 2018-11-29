# frozen_string_literal: true

class Request
  API_URL = "#{ENV['EXCHANGE_PROTOCOL']}://#{ENV['EXCHANGE_HOST']}"

  @client = Coinbase::Exchange::Client.new(ENV['KEY'], ENV['SECRET'], ENV['PW'],
                                           product_id: ENV['PRODUCT_ID'],
                                           api_url: API_URL)

  class << self
    def quote
      @client.orderbook
    end

    def depth
      @client.orderbook(level: 2)
    end

    def order(order_id)
      @client.order(order_id)
    end

    def open_orders
      @client.orders(status: 'open', product_id: ENV['PRODUCT_ID']) do |resp|
        # A block here gets all orders, whereas inline would be paginated.
        # Strangely, it returns non-JSON.
        @resp = resp
      end
      @resp.to_json
    end

    def filled_order(order_id)
      @client.fills(order_id: order_id)
    end

    def funds
      @client.accounts
    end

    def sell_order(params)
      info = "#{params[:quantity]} #{ENV['BASE_CURRENCY']} @ $#{params[:ask]}"
      Bot.log("Limit SELL params: #{info}")
      @client.sell(params[:quantity], params[:ask])
    end

    def buy_order(params)
      info = "#{params[:quantity]} #{ENV['BASE_CURRENCY']}, $#{params[:bid]}"
      Bot.log("Limit BUY params: #{info}")
      @client.buy(params[:quantity], params[:bid], stp: 'cn')
    end

    def cancel_order(order_id)
      @client.cancel(order_id)
    end

    def products
      @client.products
    end

    def currencies
      @client.currencies
    end
  end
end
