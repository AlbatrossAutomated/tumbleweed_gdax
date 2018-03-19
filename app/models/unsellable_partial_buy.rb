# frozen_string_literal: true

class UnsellablePartialBuy < ApplicationRecord
  validates :base_currency_purchased, numericality: { greater_than: 0.0 }

  def self.create_from_buy(buy_order)
    size = BigDecimal.new(buy_order['filled_size'])
    price = BigDecimal.new(buy_order['price'])
    fee = BigDecimal.new(buy_order['fill_fees'])

    create(base_currency_purchased: size,
           buy_price: price,
           buy_fee: fee,
           buy_order_id: buy_order['id'],
           trade_pair: ENV['PRODUCT_ID'])
  end
end
