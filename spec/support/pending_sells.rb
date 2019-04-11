# frozen_string_literal: true

RSpec.shared_examples_for 'pending sells' do
  let(:lowest_ask) { 11.52 }

  before do
    create(:flipped_trade, buy_price: 11.50, sell_price: 11.55, trade_pair: ENV['PRODUCT_ID'])
    create(:flipped_trade, buy_price: 11.47, sell_price: lowest_ask, trade_pair: ENV['PRODUCT_ID'])
    create(:flipped_trade, buy_price: 11.53, sell_price: 11.58, trade_pair: ENV['PRODUCT_ID'])
  end
end
