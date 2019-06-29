# frozen_string_literal: true

class FlippedTrade < ApplicationRecord
  extend Rounding

  scope :sold, -> { where(sell_pending: false) }
  # TODO: Add another method for pending_sells w/o regard for trade_pair, i.e., all.
  scope :pending_sells, -> { where(sell_pending: true, trade_pair: ENV['PRODUCT_ID']) }

  def self.quote_currency_profit
    sold.sum(&:quote_currency_profit)
  end

  def self.base_currency_profit
    all.sum(&:base_currency_profit)
  end

  def self.flip_count
    sold.count
  end

  def self.create_from_buy(buy_order)
    price = BigDecimal(buy_order['price'])
    quantity = BigDecimal(buy_order['filled_size'])
    fee = BigDecimal(buy_order['fill_fees'])

    create(base_currency_purchased: quantity,
           buy_price: price,
           buy_fee: fee,
           cost: (price * quantity) + fee,
           buy_order_id: buy_order['id'],
           trade_pair: buy_order['product_id'])
  end

  def self.lowest_ask
    pending_sells.minimum(:sell_price)
  end

  def reconcile(sold_order)
    # If fee(s), executed price may be different than requested. Fees and
    # quantity are always accurate from /orders, as is price for maker orders.
    # Getting accurate price for taker orders requires calling a different
    # API endpoint (/fills).

    Trader.consecutive_buys = 0
    Bot.log("Consecutive buy count set to #{Trader.consecutive_buys}")
    self.sell_fee = BigDecimal(sold_order['fill_fees'])
    reconcile_buy_side
    reconcile_sell_side
    self.quote_currency_profit = revenue - cost
    finalize_trade
  end

  def reconcile_buy_side
    loop do
      @fill = RequestUsher.execute('filled_order', buy_order_id)
      break if @fill.any?
    end

    cost = @fill.sum do |f|
      BigDecimal(f['price']) * BigDecimal(f['size'])
    end
    self.buy_price = cost / base_currency_purchased # average price

    self.cost = cost + buy_fee
    # ^ first set in .create_from_buy with /order data; overwrite here with actuals from
    # /fills, as order settlment may have involved multiple sub-fills w/different prices
  end

  def reconcile_sell_side
    loop do
      @fill = RequestUsher.execute('filled_order', sell_order_id)
      break if @fill.any?
    end

    revenue = @fill.sum do |f|
      BigDecimal(f['price']) * BigDecimal(f['size'])
    end

    self.sell_price = revenue / base_currency_purchased # average price
    self.revenue = revenue
    self.cost = cost + sell_fee
  end

  def finalize_trade
    self.sell_pending = false

    qc_profit_msg = FlippedTrade.qc_tick_rounded(quote_currency_profit)
    msg = "Id: #{id}, Quote Currency Profit: #{qc_profit_msg}, Fee: #{sell_fee}."
    Bot.log(msg)

    save
  end
end
