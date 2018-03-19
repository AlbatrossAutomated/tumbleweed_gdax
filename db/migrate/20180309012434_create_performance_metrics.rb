class CreatePerformanceMetrics < ActiveRecord::Migration[5.1]
  def change
    create_table :performance_metrics do |t|
      t.decimal :base_currency_for_sale
      t.decimal :best_bid
      t.decimal :quote_currency_balance
      t.decimal :base_currency_balance
      t.decimal :quote_currency_profit
      t.decimal :base_currency_profit
      t.decimal :portfolio_quote_currency_value
      t.decimal :quote_value_of_base

      t.timestamps null: false
    end
  end
end
