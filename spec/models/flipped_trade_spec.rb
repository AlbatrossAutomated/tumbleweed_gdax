# frozen_string_literal: true

require 'rails_helper'

RSpec.describe FlippedTrade, type: :model do
  include Rounding

  describe 'class methods' do
    let(:profit) { 0.05 }
    let(:flipped_trades) do
      create_list(:flipped_trade, 3, :sell_executed, quote_currency_profit: profit)
    end
    let(:pending_sells) { create_list(:flipped_trade, 3) }
    let(:completed) { FlippedTrade.where(sell_pending: true) }
    let(:completed_count) { completed.count }

    before do
      flipped_trades
      pending_sells
    end

    describe '.sold' do
      it 'does stuff'
    end

    describe '.create_from_buy' do
      it 'does stuff'
    end

    describe '.quote_currency_profit' do
      it "returns the sum of all records' quote_currency profits" do
        total_profit = qc_tick_rounded(completed_count * profit)
        expect(FlippedTrade.quote_currency_profit).to eq total_profit
      end
    end

    describe '.flipped_trades' do
      it 'returns a count of completed trades' do
        expect(FlippedTrade.flip_count).to eq completed_count
      end
    end

    describe '.lowest_ask' do
      include_examples 'pending sells'

      it 'returns the lowest ask price of pending sells' do
        expect(FlippedTrade.lowest_ask).to eq lowest_ask
      end
    end
  end

  describe '#reconcile' do
    subject { ft.reconcile(sell_order) }

    context 'buy and sell are makers' do
      let(:ft) { FlippedTrade.last }
      let(:sell_order) { maker_sell_order }
      let(:buy_size) { BigDecimal(maker_buy_order['size']) }
      let(:buy_price) { BigDecimal(maker_buy_order['price']) }
      let(:buy_fee) { BigDecimal(maker_buy_order['fill_fees']) }
      let(:sell_size) { BigDecimal(maker_sell_order['size']) }
      let(:sell_price) { BigDecimal(maker_sell_order['price']) }
      let(:sell_fee) { BigDecimal(maker_sell_order['fill_fees']) }
      let(:cost) { (buy_price * buy_size) + buy_fee + sell_fee }
      let(:revenue) { sell_size * sell_price }
      let(:profit) { revenue - cost }

      before do
        create_flipped_trade(maker_buy_order, maker_sell_order)
      end

      it_behaves_like 'a flipped trade reconciler'
    end

    context 'buy is a taker and sell is a maker' do
      let(:ft) { FlippedTrade.last }
      let(:sell_order) { maker_sell_order }
      let(:buy_size) { BigDecimal(taker_buy_order['size']) }
      let(:buy_fee) { BigDecimal(taker_buy_order['fill_fees']) }
      let(:sell_fee) { BigDecimal(maker_sell_order['fill_fees']) }
      let(:cost_less_fee) do
        taker_buy_fill.sum do |x|
          BigDecimal(x['price']) * BigDecimal(x['size'])
        end
      end
      let(:buy_price) { cost_less_fee / buy_size }
      let(:cost) { cost_less_fee + buy_fee + sell_fee }
      let(:sell_size) { BigDecimal(maker_sell_order['size']) }
      let(:sell_price) { BigDecimal(maker_sell_order['price']) }
      let(:revenue) { sell_size * sell_price }
      let(:profit) { revenue - cost }

      before do
        create_flipped_trade(taker_buy_order, maker_sell_order)
      end

      it_behaves_like 'a flipped trade reconciler'
    end

    context 'buy is a maker and sell is a taker' do
      let(:ft) { FlippedTrade.last }
      let(:sell_order) { taker_sell_order }
      let(:buy_size) { BigDecimal(maker_buy_order['size']) }
      let(:buy_price) { BigDecimal(maker_buy_order['price']) }
      let(:buy_fee) { BigDecimal(maker_buy_order['fill_fees']) }
      let(:sell_size) { BigDecimal(taker_sell_order['size']) }
      let(:sell_fee) { BigDecimal(taker_sell_order['fill_fees']) }
      let(:cost) { (buy_size * buy_price) + buy_fee + sell_fee }
      let(:revenue) do
        taker_sell_fill.sum do |fill|
          BigDecimal(fill['price']) * BigDecimal(fill['size'])
        end
      end
      let(:sell_price) { revenue / sell_size }
      let(:profit) { revenue - cost }

      before do
        create_flipped_trade(maker_buy_order, taker_sell_order)
      end

      it_behaves_like 'a flipped trade reconciler'
    end

    context 'buy is a taker and sell is a taker' do
      let(:ft) { FlippedTrade.last }
      let(:sell_order) { taker_sell_order }
      let(:buy_size) { BigDecimal(taker_buy_order['size']) }
      let(:buy_fee) { BigDecimal(taker_buy_order['fill_fees']) }
      let(:sell_size) { BigDecimal(taker_sell_order['size']) }
      let(:sell_fee) { BigDecimal(taker_sell_order['fill_fees']) }
      let(:cost_less_fee) do
        taker_buy_fill.sum do |fill|
          BigDecimal(fill['price']) * BigDecimal(fill['size'])
        end
      end
      let(:revenue) do
        taker_sell_fill.sum do |fill|
          BigDecimal(fill['price']) * BigDecimal(fill['size'])
        end
      end
      let(:buy_price) { cost_less_fee / buy_size }
      let(:cost) { (buy_size * buy_price) + buy_fee + sell_fee }
      let(:sell_price) { revenue / sell_size }
      let(:profit) { revenue - cost }

      before do
        create_flipped_trade(taker_buy_order, taker_sell_order)
      end

      it_behaves_like 'a flipped trade reconciler'
    end
  end
end
