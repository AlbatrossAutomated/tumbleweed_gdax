# frozen_string_literal: true

class UnsellablePartialBuy < ApplicationRecord
  validates :base_currency_purchased, numericality: { greater_than: 0.0 }

  def self.create_from_buy(buy_order)
    size = BigDecimal(buy_order['filled_size'])
    price = BigDecimal(buy_order['price'])
    fee = BigDecimal(buy_order['fill_fees'])

    create(base_currency_purchased: size,
           buy_price: price,
           buy_fee: fee,
           buy_order_id: buy_order['id'],
           trade_pair: buy_order['product_id'])
  end
end
