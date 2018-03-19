class CreateUnsellablePartialBuys < ActiveRecord::Migration[5.1]
  def change
    create_table :unsellable_partial_buys do |t|
      t.string :trade_pair, :string, default: ''
      t.decimal :base_currency_purchased
      t.decimal :buy_price
      t.decimal :buy_fee, default: 0.0, null: false
      t.string :buy_order_id

      t.timestamps null: false
    end
  end
end
