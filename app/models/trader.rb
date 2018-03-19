# frozen_string_literal: true

class Trader
  class << self
    attr_accessor :consecutive_buys

    def begin_trade_cycle
      loop do
        # When running after code changes to Trader it can be handy to see the call stack size here.
        Bot.log("Call stack #{caller.size}")
        Bot.mantra if BotSettings::PRINT_MANTRA
        Sentinel.sync_executed_sells
        SettingsValidator.validate
        params = Decide.scrum_params
        id = place_scrum(params)['id']
        rescrum_or_straddle(id, params[:bid])
      end
    end

    def maybe_idle(params)
      loop do
        break if Decide.affordable?(params)
      end
    end

    def place_scrum(params)
      resp = place_buy(params)
      Bot.log("SCRUM placed. Resp:", resp)
      resp
    end

    def rescrum_or_straddle(id, bid)
      scrum_status = monitor_scrum(id, bid)

      if scrum_status[:buy_down]
        buy_down = place_buy_down(bid)

        if buy_down[:monitor_straddle]
          straddle = monitor_straddle(buy_down[:buy_order_id], buy_down[:bid])
        end
      end
    end

    def monitor_scrum(id, bid)
      loop do
        Bot.log("Trades flipped: #{FlippedTrade.flip_count}")

        buy_order = RequestUsher.execute('order', id)
        handle_filled_scrum(buy_order) && break if buy_filled?(buy_order)

        if Decide.bid_again?(bid)
          @status = cancel_buy(id)
          break
        end
      end
      @status
    end

    def buy_filled?(buy_order)
      buy_order['settled'] && buy_order['done_reason'] == 'filled'
    end

    def handle_filled_scrum(buy_order)
      Bot.log('The SCRUM filled')
      handle_filled_buy(buy_order)
      @status = { buy_down: true }
    end

    def handle_filled_buy(buy_order)
      Bot.log("Possible API response w/wrong 'filled_size' causing error on sell side: ", buy_order, :debug)
      Trader.consecutive_buys = Trader.consecutive_buys.to_i + 1
      flipped_trade = FlippedTrade.create_from_buy(buy_order)
      place_sell(flipped_trade, buy_order)
    end

    def place_sell(flipped_trade, buy_order)
      params = Decide.sell_params(buy_order)
      sell_resp = RequestUsher.execute('sell_order', params)
      base_profit = BigDecimal.new(buy_order["filled_size"]) - params[:quantity]

      flipped_trade.update_attributes(sell_price: params[:ask],
                                      sell_order_id: sell_resp['id'],
                                      base_currency_profit: base_profit)
      Bot.log("SELL placed. Response: ", sell_resp)
    end

    def place_buy_down(previous_bid)
      return chill if no_trade_zone?

      params = Decide.buy_down_params(previous_bid)
      buy_resp = place_buy(params)

      Bot.log("BUY DOWN placed. Response: ", buy_resp)
      monitor_straddle_trigger(buy_resp['id'], params[:bid])
    end

    def no_trade_zone?
      Bot.log("Consecutive Buys: #{Trader.consecutive_buys}")
      (Trader.consecutive_buys % BotSettings::CHILL_PARAMS[:consecutive_buys]).zero?
    end

    def chill
      start_time = Time.zone.now
      Bot.log("No trade zone in effect for #{BotSettings::CHILL_PARAMS[:wait_time]} minutes.")

      loop do
        break if sells_executed?
        break if wait_time_expired?(start_time)
      end

      { scrum: true }
    end

    def sells_executed?
      sell_orders = RequestUsher.execute('open_orders').select { |ord| ord['side'] == 'sell' }
      executed_sells = Sentinel.find_executed_sells(sell_orders).any?
      Bot.log("Sell(s) executed!") if executed_sells
      executed_sells
    end

    def wait_time_expired?(start_time)
      minutes_passed = ((Time.zone.now - start_time) / 60).round(2)
      expired = minutes_passed >= BotSettings::CHILL_PARAMS[:wait_time]
      Bot.log("Wait time expired. Resuming trading") if expired
      expired
    end

    def place_rebuy
      params = Decide.rebuy_params
      buy_resp = place_buy(params)

      Bot.log("REBUY placed. Response: ", buy_resp)
      monitor_straddle_trigger(buy_resp['id'], params[:bid])
    end

    def place_buy(params)
      maybe_idle(params)
      RequestUsher.execute('buy_order', params)
    end

    def monitor_straddle_trigger(id, bid)
      {
        monitor_straddle: true,
        buy_order_id: id,
        bid: bid
      }
    end

    def monitor_straddle(buy_order_id, bid)
      @buy_order_id = buy_order_id
      @bid = bid

      maintain_positions

      { scrum: true }
    end

    def maintain_positions
      loop do
        @sell_side_stats = sell_side_stats

        if @sell_side_stats[:sold].positive?
          Bot.log("SELL(s) FILLED!!")
          cancel_buy(@buy_order_id)
          break if @sell_side_stats[:pending].zero?
          break if !BotSettings::ORDER_BACKFILLING && backfill_price_gap?
          straddle_rebuy
        end

        break if check_buy_side == :scrum
      end
    end

    def backfill_price_gap?
      lowest_ask = FlippedTrade.lowest_ask
      highest_sold = @sell_side_stats[:highest_sold]
      price_gap = lowest_ask - highest_sold

      if price_gap > BotSettings::BUY_DOWN_INTERVAL
        Bot.log("Backfill price gap encountered. Backfill setting is '#{BotSettings::ORDER_BACKFILLING}'")
        return true
      end

      false
    end

    def straddle_rebuy
      rebuy = place_rebuy
      @buy_order_id = rebuy[:buy_order_id]
      @bid = rebuy[:bid]
    end

    def check_buy_side
      buy_order = RequestUsher.execute('order', @buy_order_id)

      if buy_order['settled']
        if buy_order['done_reason'] == 'filled'
          # Perhaps reconcile buy side here
          straddle_buy_down(buy_order)
        elsif buy_order['done_reason'] == 'canceled'
          Bot.log("POSSIBLE STP for buy_order:", buy_order, :warn)
        end
      end
    end

    def straddle_buy_down(buy_order)
      Bot.log("BUY DOWN FILLED!!")
      handle_filled_buy(buy_order)
      buy_down = place_buy_down(@bid)

      return :scrum if buy_down[:scrum]

      @buy_order_id = buy_down[:buy_order_id]
      @bid = buy_down[:bid]
    end

    def cancel_buy(order_id)
      # When placing/canceling an order, a 200 response from GDAX does not mean
      # the order is on the book or canceled. It indicates the order is queued for
      # processing. A cancel request can occur before a previously placed order is
      # available on the book for canceling. This occurs more frequently during
      # high trading activity, and the lag in the order getting to the book for
      # canceling increases as well.

      # If the response from /cancel_order is an array containing order_id, then
      # the order is on the book. The wrinkle here is that _that_ request also
      # has to propogate (the order isn't canceled yet). In the meantime, the
      # order may fill in part or in whole. This assessment is punted to Sentinel
      # as part of the check_for_partial_buy logic.

      tries = BotSettings::CANCEL_RETRIES

      begin
        resp = RequestUsher.execute('cancel_order', order_id)
        Bot.log("Cancel resp: ", resp)
        @resp = resp.is_a?(Hash) ? resp['message'] : resp
        raise OrderNotFoundError if @resp == 'NotFound'
      rescue OrderNotFoundError
        Bot.log("'NotFound' on cancel. Retries left: ", tries, :warn)
        retry unless (tries -= 1).zero?
      end
      cancel_result(order_id)
    end

    def cancel_result(order_id)
      return cancel_success(order_id) if @resp.include?(order_id)
      filled_before_cancel(order_id) if @resp == 'Order already done'
    end

    def cancel_success(order_id)
      Bot.log("SUCCESS canceling.")
      Sentinel.check_for_partial_buy(order_id)
      { canceled: true }
    end

    def filled_before_cancel(order_id)
      Bot.log("FAILURE canceling - Order already done")
      begin
        buy_order = RequestUsher.execute('order', order_id)
        Bot.log("Buy order response: ", buy_order)
        raise UnfilledOrderError unless buy_order['settled']
      rescue UnfilledOrderError
        msg = "Unknown exchange error - Order returned as already done on cancel," +
              " but was not retrieved as 'settled'. "
        Bot.log(msg, buy_order, :error)
        retry
      end
      handle_filled_buy(buy_order)

      { buy_down: true }
    end

    def sell_side_stats
      open_orders = RequestUsher.execute('open_orders')
      log_price_positions(open_orders)

      open_sells = open_orders.select { |ord| ord['side'] == 'sell' }

      @sold_ids = Sentinel.find_executed_sells(open_sells)
      @highest_sold = 'N/A' if @sold_ids.empty?

      reconcile_sales if @sold_ids.any?

      Bot.log("PENDING SELLS: #{open_sells.size}")

      sell_stats_hash
    end

    def sell_stats_hash
      # :pending query allows untracked/unpersisted manual sells to be benign.

      {
        sold: @sold_ids.size,
        pending: FlippedTrade.pending_sells.size,
        highest_sold: @highest_sold
      }
    end

    def reconcile_sales
      flipped_trades = FlippedTrade.where(sell_order_id: @sold_ids)
      Sentinel.reconcile_executed_sells(flipped_trades)
      @highest_sold = flipped_trades.max_by(&:sell_price).sell_price
    end

    def log_price_positions(open_orders)
      buy_prices = prices(open_orders, 'buy')
      sell_prices = prices(open_orders, 'sell')

      Bot.log("Buy: #{buy_prices}. Sell(s): #{sell_prices}")
    end

    def prices(open_orders, side)
      orders = open_orders.select { |ord| ord['side'] == side }.compact
      orders.map { |ord| ord['price'].to_f }
    end
  end
end
