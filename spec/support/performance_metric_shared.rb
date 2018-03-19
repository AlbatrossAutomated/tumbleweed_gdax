# frozen_string_literal: true

RSpec.shared_examples_for 'a performance_metric creator' do
  it 'creates a performance_metric record with the expected fields' do
    subject
    expect(pm.quote_currency_balance).to eq quote_bal
    expect(pm.base_currency_balance).to eq base_bal
    expect(pm.base_currency_for_sale).to eq base_currency_for_sale
    expect(pm.best_bid).to eq best_bid
    expect(pm.quote_currency_profit).to eq QuoteCurrencyProfit.current_trade_cycle
    expect(pm.base_currency_profit).to eq base_stash
    expect(pm.portfolio_quote_currency_value).to eq quote_val
    expect(pm.quote_value_of_base).to eq quote_val_of_base
  end
end
