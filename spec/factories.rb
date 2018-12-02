# frozen_string_literal: true

FactoryBot.define do
  sequence :exchange_order_id, &:to_s
  sequence :quote_currency_balance, rand(5000..6000) { |n| n }
  sequence :base_sells_total, rand(40..90) { |n| n }

  factory :flipped_trade do
    base_currency_purchased { BigDecimal('3.1123') }
    buy_price { BigDecimal('11.78') }
    sell_price { BigDecimal('11.83') }
    buy_fee { BigDecimal('0.0') }
    sell_fee { BigDecimal('0.0') }
    buy_order_id { generate(:exchange_order_id) }
    sell_order_id { generate(:exchange_order_id) }
    sell_pending { true }
    cost { (base_currency_purchased * buy_price) + buy_fee + sell_fee }

    trait :sell_executed do
      quote_currency_profit { revenue - cost }
      revenue { base_currency_purchased * sell_price }
      sell_pending { false }
    end

    trait :buy_executed do
      sell_price { nil }
      sell_order_id { nil }
    end
  end

  factory :performance_metric do
    quote_currency_balance { generate(:quote_currency_balance) }
    base_currency_for_sale { generate(:base_sells_total) }
    base_currency_balance { 0.003 }
    best_bid { 12.34 }
  end

  factory :unsellable_partial_buy do
    base_currency_purchased { 0.0083 }
    buy_price { 11.78 }
    buy_fee { 0.0 }
    buy_order_id { generate(:exchange_order_id) }
  end

  factory :ledger_entry do
    amount { 102.34 }
    description { 'Missed trades total profit' }
    category { LedgerEntry::ADJUSTMENT }
  end
end
