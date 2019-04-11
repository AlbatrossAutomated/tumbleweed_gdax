# frozen_string_literal: true

class Sentinel
  class << self
    def sync_executed_sells
      Bot.log('Checking if any sells executed')
      exchange_sell_orders = RequestUsher.execute('open_orders').select { |ord| ord['side'] == 'sell' }
      sold_ids = find_executed_sells(exchange_sell_orders)

      return Bot.log('No sells executed') if sold_ids.empty?

      flipped_trades = FlippedTrade.where(sell_order_id: sold_ids)
      reconcile_executed_sells(flipped_trades)
      Bot.log("#{sold_ids.size} sells executed")
    end

    def find_executed_sells(exchange_sell_orders)
      exchange_sell_ids = exchange_sell_orders.map { |ord| ord['id'] }
      db_pending = FlippedTrade.pending_sells
      db_sell_ids = db_pending.select { |ft| ft.trade_pair == ENV['PRODUCT_ID'] }.map(&:sell_order_id)
      possibly_sold_ids = db_sell_ids - exchange_sell_ids

      possibly_sold_ids.empty? ? [] : confirmed_sold_ids(possibly_sold_ids)
    end

    def confirmed_sold_ids(possibly_sold_ids)
      # A sell order is placed and the bot cycles back around to monitor positions.
      # It calls /open_orders, but the just-placed sell order is not in the response.
      # Did the sell order execute, or is there a lag on the exchange in persisting
      # the order to the book? This determines which.

      Bot.log("Possible sales: ", possibly_sold_ids)

      confirmed_sold = []

      possibly_sold_ids.each do |id|
        resp = RequestUsher.execute('order', id)
        next unless resp['settled']

        Bot.log("Confirmed sold:", resp)

        confirmed_sold << id
      end

      confirmed_sold
    end

    def reconcile_executed_sells(flipped_trades)
      flipped_trades.each do |ft|
        sold_order = RequestUsher.execute('order', ft.sell_order_id)
        msg = "Sentinel reconcile #{sold_order}, ID: #{ft.sell_order_id}"
        Bot.log(msg, nil, :debug) if sold_order['message']

        next if sold_order['message']

        ft.reconcile(sold_order)
      end
    end

    def check_for_partial_buy(buy_order_id)
      # If the order is really canceled, it should return 'NotFound'.
      # If size is '0.0', then the order cancel hasn't propagated,
      # and could partially/fully fill. Retry until 'NotFound'
      # or resp['settled'] = true.

      Bot.log("Checking for partial fill...")

      loop do
        @buy_order = RequestUsher.execute('order', buy_order_id)
        Bot.log("Buy order response after CANCEL: ", @buy_order, :debug)
        break if @buy_order['settled'] || (@buy_order['message'] == 'NotFound')
      end

      return Bot.log("No partial fill detected") if @buy_order['message'] == 'NotFound'
      return UnsellablePartialBuy.create_from_buy(@buy_order) if unsellable?

      sell_partial_buy(@buy_order)
      # For both unsellable and sellable, I think there is an edge case here during
      # high exchange activity where 'filled_size' could be inaccurate (less than actual).
      # This would leave unaccounted for crypto in the exchange account. It might
      # be worth polling again, or checking /fills/:id if that proves to be more
      # accurate.
    end

    def unsellable?
      @buy_order['filled_size'].to_f < ENV['MIN_TRADE_AMT'].to_f
    end

    def sell_partial_buy(partial_buy)
      ft = FlippedTrade.create_from_buy(partial_buy)
      params = Decide.sell_params(partial_buy)
      sell_resp = RequestUsher.execute('sell_order', params)

      ft.update(sell_price: params[:ask], sell_order_id: sell_resp['id'])
      Bot.log("A PARTIAL SELL order was placed: ", sell_resp)
    end

    # **************************************************************************
    # In the event of profit taking, where the sum of all profits from
    # flipped_trades results in an acceptable level gain in Portfolio Value,
    # it may make sense to cancel all pending sells and sell them at market price.
    # This method would update the flipped_trade records to reflect the
    # consolidation. The other option is to manually delete the flipped_trade's
    # where `sell_pending: true` after they are canceled/consildated and sold
    # on the exchange. The trade off is losing a db accounting of where the revenue
    # for the consolidated sell came from.

    # pv_goal = pv_start + some_nominal_gain
    # some_nominal_gain = pv_start * acceptable_gain_over_time_period,e.g., 1% in a day,
    # 4% in a week, 8% in a month, etc.
    # possible_pv = revenue from canceling pending sells and selling their total quantity at market price.
    # - possible_pv: A consideration here is to check the buy side of the book in
    #   terms of quantities at what prices, i.e., the best bid may not cover the
    #   consolidated sell's quantity. An accurate projection of revenue needs to
    #   account for quanitites at each price on the buy side that would fill the
    #   consolidated sell fully. Takers fees also need accounting for.

    # if possible_pv >= pv_goal
    #    consolidate and sell:
    #    1) cancel all open orders
    #    2) check that they all canceled - update if any executed before cancel
    #    3) sell all quantities at market price
    #    4) either create one FlippedTrade that records the buy and sell consildation,
    #       or proportionally divide the revenue amongst pending sells. If the former,
    #       all FlippedTrade.pending_sells should be deleted.
    #    5) create LedgerEntry, category: 'adjustment', desc: 'Profit taking', amount: ??
    #    6) Trader.begin_trade_cycle should fire after profit_taking
    # end
  end
end
