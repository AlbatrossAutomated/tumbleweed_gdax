# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PerformanceMetric, type: :model do
  include Rounding

  describe '.record' do
    let(:quote) { JSON.parse(file_fixture('quote.json').read) }
    let(:best_bid) { BigDecimal(quote['bids'][0][0]) }
    let(:funds) { JSON.parse(file_fixture('funds.json').read) }
    let(:open_orders) { JSON.parse(file_fixture('open_orders.json').read) }
    let(:quote_bal) do
      amount = funds.detect { |fund| fund['currency'] == ENV['QUOTE_CURRENCY'] }['available']
      BigDecimal(amount)
    end
    let(:base_bal) do
      amount = funds.detect { |fund| fund['currency'] == ENV['BASE_CURRENCY'] }['available']
      BigDecimal(amount)
    end
    let(:base_currency_for_sale) do
      amount = funds.detect { |f| f['currency'] == ENV['BASE_CURRENCY'] }['hold']
      BigDecimal(amount)
    end
    let(:cost_of_buy) do
      buy_order = open_orders.select { |ord| ord['side'] == 'buy' }.compact.first
      price = BigDecimal(buy_order['price'])
      size = BigDecimal(buy_order['size'])
      price * size
    end
    let(:quote_val_of_base) { best_bid * (base_bal + base_currency_for_sale) }
    let(:quote_val) { quote_bal + quote_val_of_base + cost_of_buy }
    let(:log_msg) do
      "Portfolio Value: #{qc_tick_rounded(quote_val)}"
    end
    let(:trades) { FlippedTrade.all }
    let(:flipped) { trades.where(sell_pending: false) }
    let(:pm) { PerformanceMetric.last }
    let(:base_stash) { 0.0 }

    subject { PerformanceMetric.record }

    before do
      create_list(:flipped_trade, 3, :sell_executed)
      create(:flipped_trade, sell_pending: true)
      allow(Bot).to receive(:log)
    end

    it "logs the portfolio's value" do
      expect(Bot).to receive(:log).with(log_msg)
      subject
    end

    it_behaves_like 'a performance_metric creator'

    context 'there are unsellables' do
      before do
        create(:unsellable_partial_buy, base_currency_purchased: base_bal)
      end

      it_behaves_like 'a performance_metric creator'
    end
  end
end
