# frozen_string_literal: true

RSpec.shared_examples_for 'filled sell orders' do
  let(:open_orders) { file_fixture('open_orders.json').read }
  let(:sell_orders) do
    JSON.parse(open_orders).select { |ord| ord['side'] == 'sell' }
  end
  let(:still_open) { [sell_orders[0]].to_json }
  let(:still_open_ids) do
    JSON.parse(still_open).map { |ord| ord['id'] }
  end
  let(:write_lag_still_open) { [sell_orders[0], sell_orders[1]].to_json }
  let(:write_lag_still_open_ids) do
    JSON.parse(still_open).map { |ord| ord['id'] }
  end
  let(:sold) { sell_orders[1..2] }
  let(:sold_ids) do
    sold.map { |ord| ord['id'] }
  end
  let(:highest_sold) do
    sold.map { |ord| ord['price'].to_f.round(2) }.max
  end

  def create_flipped_trades(open_orders)
    JSON.parse(open_orders).each do |ord|
      next if ord['side'] == 'buy'

      sell_price = BigDecimal(ord['price'])
      buy_price = sell_price - BotSettings::PROFIT_INTERVAL
      size = BigDecimal(ord['size'])
      create(:flipped_trade, buy_price: buy_price, base_currency_purchased: size,
                             cost: buy_price * size, sell_price: sell_price,
                             sell_order_id: ord['id'])
    end
  end
end
