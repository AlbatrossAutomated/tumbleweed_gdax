# frozen_string_literal: true

class Decide
  extend Rounding

  class << self
    def scrum_params
      best_bid = RequestUsher.execute('quote')['bids'][0][0].to_f
      bid = qc_tick_rounded(best_bid)

      {
        bid: bid,
        quantity: buy_quantity
      }
    end

    def buy_down_params(previous_bid)
      bid = qc_tick_rounded(previous_bid - BotSettings::BUY_DOWN_INTERVAL)
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
      bid = qc_tick_rounded(lowest_ask - straddle)

      {
        bid: bid,
        quantity: buy_quantity
      }
    end

    def buy_quantity
      valid_buy_quantity(BotSettings::QUANTITY)
    end

    def valid_buy_quantity(quantity)
      quantity = bc_tick_rounded(quantity)
      min_allowed = ENV['MIN_TRADE_AMT'].to_f

      return quantity if quantity >= min_allowed

      min_allowed
    end

    def quote_currency_balance
      funds = RequestUsher.execute('funds')
      currency = ENV['QUOTE_CURRENCY']
      balance = funds.find { |fund| fund['currency'] == currency }['available'].to_f
      hoard = BotSettings::HOARD_QC_PROFITS ? QuoteCurrencyProfit.current_trade_cycle : 0.0
      reserve = BotSettings::QC_RESERVE

      qc_tick_rounded(balance - hoard - reserve)
    end

    def affordable?(params)
      balance = quote_currency_balance
      cost = projected_buy_order_cost(params)

      Bot.log("Usable balance: #{balance}, projected cost w/fee: #{cost}")
      balance > cost
    end

    def projected_buy_order_cost(params)
      # Assume the buy_order will be a 'taker' and incur a fee when determining
      # affordability.

      cost = ((params[:bid] * params[:quantity]) * (1 + ENV['TAKER_FEE'].to_f))
      qc_tick_rounded(cost)
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
      # Buy fees and quantity are always accurate from /orders. Price is not
      # always accurate; it can differ from filled at price. Getting actual
      # price and thus actual cost requires calling /fills.

      # buy_price from /orders is used here even though it may be
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

      buy_price = BigDecimal(buy_order['price'])
      buy_quantity = BigDecimal(buy_order['filled_size'])
      fee = BigDecimal(buy_order['fill_fees'])

      Bot.log("Buy fees incurred: #{fee}")

      loop do
        @fill = RequestUsher.execute('filled_order', buy_order['id'])
        break if @fill.any?
      end

      cost_without_fee = @fill.sum do |f|
        BigDecimal(f['price']) * BigDecimal(f['size'])
      end
      cost = cost_without_fee + fee

      calculate_sell_params(buy_price, buy_quantity, cost)
    end

    def calculate_sell_params(buy_price, buy_quantity, cost)
      sell_price = qc_tick_rounded(buy_price + BotSettings::PROFIT_INTERVAL)
      projected_revenue = sell_price * buy_quantity * (1 - ENV['MAKER_FEE'].to_f)
      projected_profit = projected_revenue - cost

      return breakeven_sell_params(buy_quantity, cost, projected_profit) if projected_profit.negative?

      profitable_sell_params(buy_price, buy_quantity, projected_profit)
    end

    def breakeven_sell_params(buy_quantity, cost, projected_profit)
      # Because rounding has to occur at the decimal places of the exchange tick-size,
      # (rev - cost) can end up being slightly negative at a rounded breakeven price.
      # Some orders' breakeven prices will result in a slightly positive (rev - cost),
      # so maybe it evens out. Adding a 'QC_INCREMENT' is further assurance for a
      # non-negative profit.

      ask = qc_tick_rounded(cost / buy_quantity) + ENV['QC_INCREMENT'].to_f
      msg = "#{ENV['QUOTE_CURRENCY']} profit would be #{qc_tick_rounded(projected_profit)}. " \
            "Selling at breakeven: #{ask}."
      Bot.log(msg, nil, :warn)

      sell_params_hash(ask, buy_quantity)
    end

    def profitable_sell_params(buy_price, buy_quantity, projected_profit)
      ask = buy_price + BotSettings::PROFIT_INTERVAL
      log_sell_side(ask, projected_profit)
      sell_params_hash(qc_tick_rounded(ask), buy_quantity)
    end

    def sell_params_hash(ask, quantity)
      {
        ask: ask,
        quantity: quantity
      }
    end

    def log_sell_side(ask, quote_profit)
      msg = "Selling at #{qc_tick_rounded(ask)} for estimated profit of #{qc_tick_rounded(quote_profit)} " \
            "#{ENV['QUOTE_CURRENCY']}."
      Bot.log(msg)
    end
  end
end
