# frozen_string_literal: true

class Decide
  extend Rounding

  class << self

    def scrum_params
      best_bid = RequestUsher.execute('quote')['bids'][0][0].to_f
      bid = round_to_qc_tick(best_bid)

      {
        bid: bid,
        quantity: buy_quantity
      }
    end

    def buy_down_params(previous_bid)
      bid = round_to_qc_tick(previous_bid - BotSettings::BUY_DOWN_INTERVAL)
      Bot.log("BDI: #{BotSettings::BUY_DOWN_INTERVAL}. Buy Down Bid: #{bid}")

      {
        bid: bid,
        quantity: buy_quantity
      }
    end

    def rebuy_params
      # Important to check db for lowest ask and not the exchange which may have
      # write lags.
      lowest_ask = FlippedTrade.lowest_ask
      straddle = BotSettings::BUY_DOWN_INTERVAL + BotSettings::PROFIT_INTERVAL
      bid = round_to_qc_tick(lowest_ask - straddle)

      {
        bid: bid,
        quantity: buy_quantity
      }
    end

    def buy_quantity
      valid_buy_quantity(BotSettings::QUANTITY)
    end

    def valid_buy_quantity(quantity)
      quantity = round_to_bc_tick(quantity)
      min_allowed = ENV['MIN_TRADE_AMT'].to_f

      return quantity if quantity >= min_allowed
      min_allowed
    end

    def quote_currency_balance
      funds = RequestUsher.execute('funds')
      currency = ENV['QUOTE_CURRENCY']
      balance = funds.find { |fund| fund['currency'] == currency }['available'].to_f
      hoard = BotSettings::HOARD_QC_PROFITS ? QuoteCurrencyProfit.current_trade_cycle : 0.0
      reserve = BotSettings::RESERVE

      round_to_qc_tick(balance - hoard - reserve)
    end

    def affordable?(params)
      balance = quote_currency_balance
      cost = buy_order_cost(params)

      Bot.log("Usable balance: #{balance}, Cost if fee: #{cost}")
      balance > cost
    end

    def buy_order_cost(params)
      # Assume the buy_order will be a 'taker' and incur a fee when determining
      # affordability.

      cost = ((params[:bid] * params[:quantity]) * (1 + ENV['BUY_FEE'].to_f))
      round_to_qc_tick(cost)
    end

    def bid_again?(current_bid)
      Bot.log("Checking BID: #{current_bid}")
      quote = RequestUsher.execute('quote')
      best_bid = quote['bids'][0][0].to_f

      return false if best_bid <= current_bid

      Bot.log("BID too low. Best bid: #{best_bid}.")
      true
    end

    def sell_params(buy_order)
      buy_price = BigDecimal.new(buy_order['price'])
      buy_quantity = BigDecimal.new(buy_order['filled_size'])
      fee = BigDecimal.new(buy_order['fill_fees'])

      Bot.log("Buy fees incurred: #{fee}")

      return maker_sell_params(buy_price, buy_quantity) if fee.zero?
      taker_sell_params(buy_order, buy_price, buy_quantity, fee)
    end

    def maker_sell_params(buy_price, buy_quantity)
      cost = buy_price * buy_quantity
      calculate_sell_params(buy_price, buy_quantity, cost)
    end

    def taker_sell_params(buy_order, buy_price, buy_quantity, fee)
      # Fees and quantity are always accurate from /orders. Price is only
      # accurate for maker orders. Getting actual price and thus actual cost
      # for taker orders requires calling a different API endpoint (/fills).

      # buy_price from /orders is passed in here even though it may be
      # inaccurate. It will only ever be equal to or lower than requested price.
      # The latter occurs in quick downturns and means the sell price placed at
      # buy_price + PI will generate higher than expected profit, which is good.
      # We also want the trader to smoothly buy the dip, which it wouldn't do if
      # we passed along the actual price from /fills. We do however
      # calculate actual cost so that .projected_profit doesn't incorrectly
      # influence breakeven pricing.

      # Essentially we let the trader think it got the requested buy price even
      # though it might have been better, and it profits more when the associated
      # sell executes. The additional risk taken on when buying a sharp dip is
      # paired with a higher possible reward.

      loop do
        @fill = RequestUsher.execute('filled_order', buy_order['id'])
        break if @fill.any?
      end

      cost_without_fee = @fill.sum do |f|
        BigDecimal.new(f['price']) * BigDecimal.new(f['size'])
      end

      cost = cost_without_fee + fee
      calculate_sell_params(buy_price, buy_quantity, cost)
    end

    def calculate_sell_params(buy_price, buy_quantity, cost)
      sell_price = round_to_qc_tick(buy_price + BotSettings::PROFIT_INTERVAL)
      projected_revenue = sell_price * buy_quantity
      profit_without_stash = projected_revenue - cost

      return breakeven_sell_params(buy_quantity, cost, profit_without_stash) if profit_without_stash.negative?
      profitable_sell_params(buy_price, buy_quantity, cost, profit_without_stash)
    end

    def breakeven_sell_params(buy_quantity, cost, profit_without_stash)
      # Because rounding has to occur at the decimal places of the exchange tick-size,
      # (rev - cost) can end up being slightly negative at a rounded breakeven price.
      # Some orders' breakeven prices will result in a slightly positive (rev - cost),
      # so maybe it evens out. Adding a 'QC_TICK_SIZE' is assurance for a slightly
      # positive result for the ones that would otherwise be slightly negative.

      ask = round_to_qc_tick(cost / buy_quantity) + ENV['QC_TICK_SIZE'].to_f
      msg = "#{ENV['QUOTE_CURRENCY']} profit would be #{round_to_qc_tick(profit_without_stash)}. " +
            "Selling at breakeven: #{ask}."
      Bot.log(msg, nil, :warn)

      {
        ask: ask,
        quantity: buy_quantity
      }
    end

    def profitable_sell_params(buy_price, buy_quantity, cost, profit_without_stash)
      ask = buy_price + BotSettings::PROFIT_INTERVAL

      if BotSettings::BC_STASH.zero?
        log_sell_side(ask, profit_without_stash, 0.0)

        {
          ask: round_to_qc_tick(ask),
          quantity: buy_quantity
        }
      else
        stash_sell_params(ask, buy_quantity, cost, profit_without_stash)
      end
    end

    def stash_sell_params(ask, buy_quantity, cost, profit_without_stash)
      profit_after_stash = profit_without_stash * (1.0 - BotSettings::BC_STASH)
      quantity_less_stash = (profit_after_stash + cost) / ask

      if quantity_less_stash <= ENV['MIN_TRADE_AMT'].to_f
        skip_stashing_params(ask, buy_quantity, profit_without_stash, quantity_less_stash)
      else
        stash = buy_quantity - quantity_less_stash
        log_sell_side(ask, profit_after_stash, stash)

        {
          ask: round_to_qc_tick(ask),
          quantity: round_to_bc_tick(quantity_less_stash)
        }
      end
    end

    def skip_stashing_params(ask, buy_quantity, profit_without_stash, quantity_less_stash)
      Bot.log("Sell size after stash would be invalid (#{round_to_bc_tick(quantity_less_stash)}). Skipping stashing.")
      log_sell_side(ask, profit_without_stash, 0.0)

      {
        ask: round_to_qc_tick(ask),
        quantity: buy_quantity
      }
    end

    def log_sell_side(ask, quote_profit, base_profit)
      msg = "Selling at #{round_to_qc_tick(ask)} for an estimated profit of #{round_to_qc_tick(quote_profit)} " +
            "#{ENV['QUOTE_CURRENCY']} and #{round_to_bc_tick(base_profit)} #{ENV['BASE_CURRENCY']}."
      Bot.log(msg)
    end

    # def _ask_price(buy_order)
    # WIP - Old reformulation from when BDI was dynamic
    #   Optimistic sell price determination assumes that sell orders
    #   will not incur a taker fee. Pessimistic assumes they will.
    #
    #   Q = Quantity purchased on the buy
    #   P = Price of the buy
    #
    #   Optimitic:
    #                    P * Q + buy_fee + QUOTE_CURRENCY_PROFIT
    #                 ---------------------------------------------
    #                         Q - BC_STASH
    #
    #   Pessimistic:
    #                   (P * Q + buy_fee + QUOTE_CURRENCY_PROFIT)
    #                 ---------------------------------------------
    #                               1 - SELL_FEE
    #        ---------------------------------------------------------------
    #                         Q - BC_STASH
    # end
  end
end
