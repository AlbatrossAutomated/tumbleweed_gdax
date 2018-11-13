# frozen_string_literal: true

class PerformanceMetric < ApplicationRecord
  extend Rounding

  class << self
    # :base_currency_for_sale -> total base currency in pending sell orders
    # :best_bid -> best market bid at time of write
    # :quote_currency_balance -> money in cash account
    # :base_currency_balance -> unsellable_partial_buy amounts
    # :quote_currency_profit -> see QuoteCurrencyProfit#current_trade_cycle
    # :base_currency_profit -> the total base currency stashed
    # :quote_value_of_base -> (base_currency_balance + base_currency_for_sale) * best_bid
    # :portfolio_quote_currency_value -> quote_currency_balance + quote_value_of_base

    def calculate
      funds = RequestUsher.execute('funds')
      best_bid = BigDecimal.new(RequestUsher.execute('quote')['bids'][0][0])

      base_for_sale = base_currency_for_sale(funds)
      quote_bal = quote_currency_balance(funds)
      base_bal = base_currency_balance(funds)
      quote_val_of_base = quote_value_of_base(base_for_sale, base_bal, best_bid)
      cost_of_buy = pending_buy_cost
      attribs(base_for_sale, best_bid, quote_bal, base_bal, quote_val_of_base, cost_of_buy)
    end

    def attribs(base_for_sale, best_bid, quote_bal, base_bal, quote_val_of_base, cost_of_buy)
      {
        base_currency_for_sale: base_for_sale, base_currency_balance: base_bal,
        best_bid: best_bid, quote_value_of_base: quote_val_of_base,
        base_currency_profit: FlippedTrade.base_currency_profit,
        quote_currency_balance: quote_bal, quote_currency_profit: quote_currency_profit,
        portfolio_quote_currency_value: quote_currency_value(quote_val_of_base, quote_bal, cost_of_buy)
      }
    end

    def record
      metric = create(calculate)
      qc_pv = metric.portfolio_quote_currency_value
      Bot.log("Portfolio Value: #{round_to_qc_tick(qc_pv)}")
    end

    def base_currency_for_sale(funds)
      amt = funds.detect { |f| f['currency'] == ENV['BASE_CURRENCY'] }['hold']
      BigDecimal.new(amt)
    end

    def base_currency_balance(funds)
      amt = funds.detect { |f| f['currency'] == ENV['BASE_CURRENCY'] }['available']
      BigDecimal.new(amt)
    end

    def quote_currency_balance(funds)
      amt = funds.detect { |f| f['currency'] == ENV['QUOTE_CURRENCY'] }['available']
      BigDecimal.new(amt)
    end

    def pending_buy_cost
      # The trader should only ever have 1 open buy order at most. If there are more,
      # then it is assumed they are manually placed orders and shouldn't be in the
      # scope of Tumbleweed's activity/performance. The API response for open orders
      # is ordered most recent to last, so the first buy order is assumed to be
      # placed by the trader.

      open_orders = RequestUsher.execute('open_orders')
      buy_order = open_orders.select { |ord| ord['side'] == 'buy' }.compact.first

      if buy_order
        price = BigDecimal.new(buy_order['price'])
        size = BigDecimal.new(buy_order['size'])
        price * size
      else
        0.0
      end
    end

    def quote_currency_profit
      QuoteCurrencyProfit.current_trade_cycle
    end

    def quote_value_of_base(base_for_sale, base_bal, best_bid)
      (base_for_sale + base_bal) * best_bid
    end

    def quote_currency_value(quote_val_of_base, quote_bal, cost_of_buy)
      quote_val_of_base + quote_bal + cost_of_buy
    end
  end
end
