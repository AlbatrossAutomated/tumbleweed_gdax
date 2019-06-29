# frozen_string_literal: true

class SettingsEstimator
  include ActiveAttr::Model

  # inputs
  attribute :buy_quantity, type: BigDecimal
  attribute :quote_currency_balance, type: BigDecimal
  attribute :reserve, type: BigDecimal, default: 0.0
  attribute :buy_fee, type: BigDecimal
  attribute :sell_fee, type: BigDecimal
  attribute :base_currency_price, type: BigDecimal
  attribute :min_trade_amount, type: BigDecimal
  attribute :profit_interval, type: BigDecimal

  # results
  attribute :trade_detailed
  attribute :sell_quantity, type: BigDecimal
  attribute :quote_profit_per_sell, type: BigDecimal
  attribute :results_errors, default: []

  validates :quote_currency_balance,
            :base_currency_price,
            :buy_quantity,
            :profit_interval, numericality: { greater_than: 0.0 }
  validates :buy_fee, :sell_fee, numericality: { greater_than_or_equal_to: 0.0 }
  validates :reserve, numericality: { greater_than_or_equal_to: 0.0 }
  validates :quote_currency_balance, numericality: { greater_than: ->(se) { se.reserve },
                                                     message: "must be more than reserve" }

  def results
    self.quote_currency_balance = quote_currency_balance - reserve
    self.sell_quantity = buy_quantity
    self.quote_profit_per_sell = calculate_quote_profit_per_sell(base_currency_price, sell_quantity)
    self.trade_detailed = calculate_trade_detailed
    add_results_errors
    self
  end

  def calculate_quote_profit_per_sell(buy_price, sell_quantity)
    (revenue(buy_price, sell_quantity) - costs(buy_price)).round(8)
  end

  def revenue(buy_price, sell_quantity)
    ask(buy_price) * sell_quantity * (1 - sell_fee_proportion)
  end

  def costs(buy_price)
    buy_price * buy_quantity * (1 + buy_fee_proportion)
  end

  def ask(buy_price)
    buy_price + profit_interval
  end

  def buy_fee_proportion
    as_proportion(buy_fee)
  end

  def sell_fee_proportion
    as_proportion(sell_fee)
  end

  def calculate_trade_detailed
    balance = quote_currency_balance
    buy_price = base_currency_price
    sell_price = base_currency_price + profit_interval

    cost, b_fee, total_cost = buy_side_trade(buy_price)
    sell_quantity, revenue, s_fee, total_revenue = sell_side_trade(sell_price)

    {
      balance: balance.round(2),
      buy_price: buy_price.round(8),
      buy_quantity: buy_quantity.round(8),
      cost: cost.round(8),
      buy_fee: b_fee.round(8),
      total_cost: total_cost.round(8),
      sell_price: sell_price.round(8),
      sell_quantity: sell_quantity.round(8),
      revenue: revenue.round(8),
      sell_fee: s_fee.round(8),
      total_revenue: total_revenue.round(8),
      quote_profit: (total_revenue - total_cost).round(8)
    }
  end

  def buy_side_trade(buy_price)
    cost = buy_price * buy_quantity
    b_fee = buy_fee_proportion * cost

    [
      cost,
      b_fee,
      cost + b_fee
    ]
  end

  def sell_side_trade(sell_price)
    sell_quantity = buy_quantity
    revenue = sell_price * sell_quantity
    s_fee = sell_fee_proportion * revenue

    [
      sell_quantity,
      revenue,
      s_fee,
      revenue - s_fee
    ]
  end

  def as_proportion(percent)
    percent / 100.0
  end

  def add_results_errors
    quantity
    negative_profit
  end

  def quantity
    buy_msg = "GDAX's minimum BUY order amount requirement is not met. Adjust your settings."
    sell_msg = "GDAX's minimum SELL order amount requirement is not met. Adjust your settings."
    results_errors << buy_msg if buy_quantity < min_trade_amount
    results_errors << sell_msg if sell_quantity < min_trade_amount
  end

  def negative_profit
    msg = "You're profit is negative."
    results_errors << msg if quote_profit_per_sell.negative?
  end
end
