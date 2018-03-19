class CreateFlippedTrades < ActiveRecord::Migration[5.1]
  def change
    create_table :flipped_trades do |t|
      t.string :trade_pair, default: ''
      t.decimal :quote_currency_profit, default: 0.0, null: false
      t.decimal :base_currency_purchased
      t.decimal :base_currency_profit, default: 0.0, null: false
      t.decimal :buy_price
      t.decimal :sell_price
      t.decimal :buy_fee, default: 0.0, null: false
      t.decimal :sell_fee, default: 0.0, null: false
      t.decimal :revenue, default: 0.0, null: false
      t.decimal :cost, default: 0.0, null: false
      t.string :buy_order_id
      t.string :sell_order_id
      t.boolean :sell_pending, default: true, null: false
      t.boolean :consolidated, default: false, null: false

      t.timestamps null: false
    end
  end
end
