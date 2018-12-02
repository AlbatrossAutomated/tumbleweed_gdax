# frozen_string_literal: true

RSpec.shared_examples_for 'a flipped trade reconciler' do
  let(:maker_buy_order) { JSON.parse(file_fixture('order_20.json').read) }
  let(:maker_sell_order) { JSON.parse(file_fixture('order_21.json').read) }
  let(:taker_buy_order) { JSON.parse(file_fixture('order_22.json').read) }
  let(:taker_sell_order) { JSON.parse(file_fixture('order_23.json').read) }
  let(:taker_buy_fill) { JSON.parse(file_fixture('fill_22.json').read) }
  let(:taker_sell_fill) { JSON.parse(file_fixture('fill_23.json').read) }
  let(:consecutive_buys) { Trader.consecutive_buys }

  before do
    allow(Bot).to receive(:log)
    Trader.consecutive_buys = 3
  end

  it 'resets Trader.consecutive_buys count' do
    subject
    expect(Trader.consecutive_buys).to eq 0
  end

  it 'updates the record with the expected fields' do
    subject

    expect(ft.base_currency_purchased).to eq buy_size
    expect(ft.base_currency_profit).to eq buy_size - sell_size
    expect(ft.buy_price).to eq buy_price
    expect(ft.buy_fee).to eq buy_fee
    expect(ft.sell_price).to eq sell_price
    expect(ft.sell_fee).to eq sell_fee
    expect(ft.cost).to eq cost
    expect(ft.revenue).to eq revenue
    expect(ft.quote_currency_profit).to eq profit
    expect(ft.sell_pending).to be false
  end

  it 'logs the actual profit' do
    subject
    msg = "Id: #{ft.id}, Quote Currency Profit: #{qc_tick_rounded(ft.quote_currency_profit)}, " \
          "Base Currency Stashed: #{ft.base_currency_profit}, Fee: #{ft.sell_fee}."

    expect(Bot).to have_received(:log).with(msg)
  end

  def create_flipped_trade(buy, sell)
    buy_size = BigDecimal(buy['size'])
    buy_price = BigDecimal(buy['price'])
    buy_fee = BigDecimal(buy['fill_fees'])
    sell_price = BigDecimal(sell['price'])
    sell_fee = BigDecimal(sell['fill_fees'])
    base_profit = buy_size - BigDecimal(sell['size'])

    create(:flipped_trade, buy_order_id: buy['id'], sell_order_id: sell['id'],
                           buy_price: buy_price, sell_price: sell_price,
                           base_currency_purchased: buy_size, sell_fee: sell_fee,
                           buy_fee: buy_fee, trade_pair: buy['product_id'],
                           cost: ((buy_price * buy_size) + buy_fee),
                           base_currency_profit: base_profit)
  end
end
