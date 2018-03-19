# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Decide, type: :model do
  let(:buy_fee_percent) { ENV['BUY_FEE'].to_f }
  let(:funds) { JSON.parse(file_fixture('funds.json').read) }
  let(:quote_currency_balance) do
    funds.detect { |f| f['currency'] == ENV['QUOTE_CURRENCY'] }['available'].to_f
  end
  let(:quote_currency_profit) { BigDecimal.new('1605.38') }
  let(:quote_currency_reserve) { BotSettings::RESERVE }
  let(:available_quote_currency) do
    (quote_currency_balance - quote_currency_profit - quote_currency_reserve).round(2)
  end
  let(:coverage) { BotSettings::COVERAGE }
  let(:buy_down_interval) { BotSettings::BUY_DOWN_INTERVAL }
  let(:accum_profit) { quote_currency_profit }
  let(:dividend) { buy_down_interval * 2 * available_quote_currency }
  let(:divisor) { bid**2 * coverage * (2 - coverage) }
  let(:depth) { JSON.parse(file_fixture('depth.json').read) }
  let(:best_bid_on_exchange) { depth['bids'][0][0].to_f }
  let(:best_ask_on_exchange) { depth['asks'][0][0].to_f }
  let(:expected_quantity) { (dividend / divisor).round(8) }

  before do
    allow(QuoteCurrencyProfit).to receive(:current_trade_cycle) { accum_profit }
  end

  context 'determining buy params' do
    describe '.affordable?' do
      before do
        allow(Decide).to receive(:quote_currency_balance) { 12.21 }
      end

      subject { Decide.affordable?(params) }

      context 'balance less quote_currency_profit is enough funds to place the buy' do
        let(:params) do
          {
            bid: 11.99,
            quantity: 1
          }
        end

        it 'is affordable' do
          expect(subject).to be true
        end
      end

      context 'balance less quote_currency_profit _not_ enough to place the buy' do
        let(:params) do
          {
            bid: 12.22,
            quantity: 1
          }
        end

        it 'is unaffordable' do
          expect(subject).to be false
        end
      end
    end

    describe '.valid_buy_quantity' do
      let(:valid) { 0.12 }
      let(:invalid) { 0.003 }

      it 'returns quantity when determined quantity is valid' do
        expect(Decide.valid_buy_quantity(valid)).to eq valid
      end

      it 'returns exchange min quantity when determined quantity is invalid' do
        expect(Decide.valid_buy_quantity(invalid)).to eq ENV["MIN_TRADE_AMT"].to_f
      end
    end

    describe '.scrum_params' do
      let(:bid) { best_bid_on_exchange }

      subject { Decide.scrum_params }

      it 'returns a bid price equal to best bid on exchange' do
        expect(subject[:bid]).to eq bid
      end

      it 'returns the expected quantity' do
        expect(subject[:quantity]).to eq expected_quantity
      end

      it 'sets buy_down_quantity' do
        subject
        expect(Decide.buy_down_quantity).to_not be_nil
      end
    end

    context 'bidding and rebidding' do
      describe '.bid_again?' do
        let(:current_bid) { best_bid_on_exchange }

        subject { Decide.bid_again?(bid) }

        it 'logs a check of bid' do
          log_msg = "Checking BID: #{current_bid}"
          expect(Bot).to receive(:log).with(log_msg)
          Decide.bid_again?(current_bid)
        end

        context 'current bid is equal to the best bid on the exchange' do
          let(:bid) { current_bid }

          it 'returns false' do
            expect(subject).to be false
          end
        end

        context 'order filled before checking bid' do
          # best_bid will be less than current in this case
          let(:high_bid) { (best_bid_on_exchange + 0.01).round(2) }
          let(:bid) { high_bid }

          it 'returns false' do
            expect(subject).to be false
          end
        end

        context 'current bid is less than best bid on exchange' do
          let(:log_msg) { "BID too low. Best bid: #{best_bid_on_exchange}." }
          let(:low_bid) { best_bid_on_exchange - 0.01 }
          let(:bid) { low_bid }

          before { allow(Bot).to receive(:log) }

          it 'logs the bid is too low' do
            expect(Bot).to receive(:log).with(log_msg)
            subject
          end

          it 'returns true' do
            expect(subject).to be true
          end
        end
      end
    end

    describe '.buy_down_params' do
      let(:previous_bid) { 11.22 }
      let(:bid) { (previous_bid - buy_down_interval).round(2) }
      let(:price_log_msg) do
        "BDI: #{buy_down_interval}. Buy Down Bid: #{bid}"
      end
      let(:covered_to_price) { previous_bid * (1 - BotSettings::COVERAGE) }

      let(:cov_log_msg) do
        "COVERAGE: #{BotSettings::COVERAGE * 100}%." +
          " Covered to: $#{covered_to_price.round(2)}."
      end

      subject { Decide.buy_down_params(previous_bid) }

      before do
        allow(Bot).to receive(:log)
      end

      it 'returns the expected bid' do
        expect(subject[:bid]).to eq bid
      end

      it 'returns the set buy_down_quantity' do
        Decide.buy_down_quantity = 100.93214323
        expect(subject[:quantity]).to eq Decide.buy_down_quantity
      end

      it 'logs the buy_down_interval and buy_down_bid' do
        expect(Bot).to receive(:log).with(price_log_msg)
        subject
      end

      it 'logs coverage info' do
        expect(Bot).to receive(:log).with(cov_log_msg)
        subject
      end
    end

    describe '.quote_currency_balance' do
      context 'quote currency is being withheld from risk pool' do
        it 'returns the quote currency balance less cummulative profit' do
          expect(Decide.quote_currency_balance).to eq available_quote_currency
        end

        context 'a positive RESERVE value is also set' do
          before { stub_const("BotSettings::RESERVE", 100.23) }

          it 'returns the quote currency balance less cummulative profit less RESERVE amount' do
            less_profit = quote_currency_balance - quote_currency_profit
            tradable_balance = (less_profit - quote_currency_reserve).round(2)
            expect(Decide.quote_currency_balance).to eq tradable_balance
          end
        end
      end

      context 'quote currency is _not_ being withheld from risk pool' do
        before { stub_const("BotSettings::HOARD_QUOTE_PROFITS", false) }

        it 'returns the quote currency balance' do
          expect(Decide.quote_currency_balance).to eq quote_currency_balance.round(2)
        end

        context 'a positive RESERVE value is set' do
          before { stub_const("BotSettings::RESERVE", 210.23) }

          it 'returns the quote currency balance less RESERVE amount' do
            tradable_balance = (quote_currency_balance - quote_currency_reserve).round(2)
            expect(Decide.quote_currency_balance).to eq tradable_balance
          end
        end
      end
    end

    describe '.rebuy_params' do
      include_examples 'pending sells'

      let(:profit_interval) { BotSettings::PROFIT_INTERVAL }
      let(:buy_down_interval) { BotSettings::BUY_DOWN_INTERVAL }
      let(:straddle) { profit_interval + buy_down_interval }
      let(:bid) { (lowest_ask - straddle).round(2) }

      subject { Decide.rebuy_params }

      it 'returns the expected bid' do
        expect(subject[:bid]).to eq bid
      end

      it 'recalculates the buy_down_quantity' do
        Decide.buy_down_quantity = 100.93214323
        expect(subject[:quantity]).to eq expected_quantity
        expect(Decide.buy_down_quantity).to eq expected_quantity
      end
    end
  end

  context 'determining ask params' do
    let(:filled_buy_order) { JSON.parse(file_fixture('order_0.json').read) }
    let(:buy_price) { BigDecimal.new(buy_order['price']) }
    let(:buy_quantity) { BigDecimal.new(buy_order['filled_size']) }
    let(:buy_fee) { BigDecimal.new(buy_order['fill_fees']) }
    let(:buy_costs) { (buy_price * buy_quantity) + buy_fee }
    let(:sell_quantity) { buy_quantity }

    context 'base currency is _not_ being stashed' do
      describe '.sell_params' do
        let(:expected_ask) do
          (buy_price + BotSettings::PROFIT_INTERVAL).round(2)
        end
        let(:projected_revenue) do
          (buy_price + BotSettings::PROFIT_INTERVAL).round(2) * sell_quantity
        end
        let(:profit) { projected_revenue - buy_costs }

        subject { Decide.sell_params(buy_order) }

        context 'no fee incurred on buy' do
          let(:log_msg1) { "Buy fees incurred: #{buy_fee}" }
          let(:log_msg2) do
            "Selling at #{expected_ask} for an estimated profit of #{profit.round(8)} " +
              "#{ENV['QUOTE_CURRENCY']} and 0.0 #{ENV['BASE_CURRENCY']}."
          end

          context 'buy order fully filled' do
            let(:buy_order) { filled_buy_order }

            it 'returns the expected ask' do
              expect(subject[:ask]).to eq expected_ask
            end

            it 'returns the expected quantity' do
              expect(subject[:quantity]).to eq sell_quantity
            end

            it 'it logs the buy_fee and determined ask_price' do
              allow(Bot).to receive(:log)
              expect(Bot).to receive(:log).with(log_msg1)
              expect(Bot).to receive(:log).with(log_msg2)
              subject
            end
          end

          context 'buy order partially filled' do
            # sanity check spec; logic should never result in a non-fee buy
            # selling at anything other than buy_price + PROFIT_INTERVAL,
            # regardless of quantity

            let(:quantity) { ENV['MIN_TRADE_AMT'] }
            let(:buy_order) do
              filled_buy_order.merge('filled_size' => quantity)
            end

            it 'returns the expected ask price' do
              expect(subject[:ask]).to eq expected_ask
            end
          end
        end

        context 'a fee is incurred on the buy' do
          context 'it is still profitable at the set PROFIT_INTERVAL' do
            let(:filled_buy_order) do
              JSON.parse(file_fixture('order_22.json').read)
            end
            let(:price) { BigDecimal.new(filled_buy_order['price']) }
            let(:quantity) { BigDecimal.new(filled_buy_order['filled_size']) }
            let(:buy_order) { filled_buy_order }

            before do
              stub_const("BotSettings::PROFIT_INTERVAL", 0.05)
              FlippedTrade.create_from_buy(filled_buy_order)
            end

            it 'returns the expected ask price' do
              expect(subject[:ask]).to eq expected_ask
            end

            context 'API lags writing to /fills' do
              let(:fill) { file_fixture('fill_22.json').read }

              before do
                allow(Request).to receive(:filled_order).and_return('[]', fill)
              end

              it 'calls the API until the order is written to /fills' do
                expect(Request).to receive(:filled_order).exactly(:twice)
                subject
              end
            end
          end

          context 'it is still profitable when filling far below requested bid' do
            let(:filled_buy_order) do
              JSON.parse(file_fixture('order_24.json').read)
            end
            let(:price) { BigDecimal.new(filled_buy_order['price']) }
            let(:quantity) { BigDecimal.new(filled_buy_order['filled_size']) }
            let(:buy_order) { filled_buy_order }

            before do
              stub_const("BotSettings::PROFIT_INTERVAL", 0.03)
              FlippedTrade.create_from_buy(filled_buy_order)
            end

            it 'returns the expected ask price' do
              expect(subject[:ask]).to eq expected_ask
            end
          end

          context 'it is unprofitable at the set PROFIT_INTERVAL' do
            let(:filled_buy_order) do
              JSON.parse(file_fixture('order_22.json').read)
            end
            let(:price) { BigDecimal.new(filled_buy_order['price']) }
            let(:quantity) { BigDecimal.new(filled_buy_order['filled_size']) }
            let(:fee) { BigDecimal.new(filled_buy_order['fill_fees']) }
            let(:buy_order) { filled_buy_order }
            let(:cost) { (price * quantity) + fee }
            let(:expected_breakeven_ask) { (cost / quantity).round(2) + 0.01 }
            let(:breakeven_msg) { /Selling at breakeven/ }

            before do
              stub_const("BotSettings::PROFIT_INTERVAL", 0.02)
              allow(Bot).to receive(:log)
              FlippedTrade.create_from_buy(filled_buy_order)
            end

            it 'logs intent to sell at breakeven' do
              subject
              expect(Bot).to have_received(:log).with(breakeven_msg, nil, :warn)
            end

            it 'returns the expected breakeven ask price' do
              expect(subject[:ask]).to eq expected_breakeven_ask
            end
          end
        end
      end
    end

    context 'base currency _is_ being stashed' do
      before { stub_const("BotSettings::BASE_CURRENCY_STASH", 0.1) }

      describe '.sell_params' do
        let(:stash) { BotSettings::BASE_CURRENCY_STASH }
        let(:expected_ask) do
          (buy_price + BotSettings::PROFIT_INTERVAL).round(2)
        end
        let(:projected_revenue) do
          (buy_price + BotSettings::PROFIT_INTERVAL).round(2) * sell_quantity
        end
        let(:profit_without_stash) { projected_revenue - buy_costs }
        let(:profit_with_stash) { profit_without_stash * (1.0 - stash) }
        let(:sell_quantity_less_stash) do
          ((profit_with_stash + buy_costs) / expected_ask).round(8)
        end

        subject { Decide.sell_params(buy_order) }

        context 'no fee incurred on buy' do
          let(:base_currency_profit) do
            (sell_quantity - sell_quantity_less_stash).round(8)
          end
          let(:log_msg1) { "Buy fees incurred: #{buy_fee}" }
          let(:log_msg2) do
            "Selling at #{expected_ask} for an estimated profit of #{profit_with_stash.round(8)} " +
              "#{ENV['QUOTE_CURRENCY']} and #{base_currency_profit} #{ENV['BASE_CURRENCY']}."
          end

          context 'buy order fully filled' do
            let(:buy_order) { filled_buy_order }

            it 'returns the expected ask' do
              expect(subject[:ask]).to eq expected_ask
            end

            it 'returns the expected quantity' do
              expect(subject[:quantity]).to eq sell_quantity_less_stash
            end

            it 'it logs the zero buy_fee and determined ask_price' do
              allow(Bot).to receive(:log)
              expect(Bot).to receive(:log).with(log_msg1)
              expect(Bot).to receive(:log).with(log_msg2)
              subject
            end
          end

          context 'buy order partially filled' do
            let(:quantity) { "1.00000000" }
            let(:buy_order) do
              filled_buy_order.merge('filled_size' => quantity)
            end

            it 'returns the expected ask' do
              expect(subject[:ask]).to eq expected_ask
            end

            it 'returns the expected quantity' do
              expect(subject[:quantity]).to eq sell_quantity_less_stash
            end
          end

          context 'sell quantity less stash would not meet the exchange min trade amount' do
            let(:quantity) { ENV['MIN_TRADE_AMT'] }
            let(:buy_order) do
              filled_buy_order.merge('filled_size' => quantity)
            end
            let(:log_msg) do
              "Sell size after stash would be invalid (#{sell_quantity_less_stash.round(8)}). " +
                "Skipping stashing."
            end

            it 'logs it is skipping stashing' do
              allow(Bot).to receive(:log)
              expect(Bot).to receive(:log).with(log_msg)
              subject
            end

            it 'returns the expected ask' do
              expect(subject[:ask]).to eq expected_ask
            end

            it 'returns the buy quantity and skips stashing' do
              expect(subject[:quantity]).to eq BigDecimal.new(quantity)
            end
          end
        end

        context 'a fee is incurred on the buy' do
          context 'it is still profitable at the set PROFIT_INTERVAL' do
            let(:filled_buy_order) do
              JSON.parse(file_fixture('order_22.json').read)
            end
            let(:price) { BigDecimal.new(filled_buy_order['price']) }
            let(:quantity) { BigDecimal.new(filled_buy_order['filled_size']) }
            let(:fee) { BigDecimal.new(filled_buy_order['fill_fees']) }
            let(:buy_costs) { actual_costs('fill_22.json') }
            let(:buy_order) { filled_buy_order }

            before do
              stub_const("BotSettings::PROFIT_INTERVAL", 0.05)
              FlippedTrade.create_from_buy(filled_buy_order)
            end

            it 'returns the expected ask' do
              expect(subject[:ask]).to eq expected_ask
            end

            it 'returns the expected quantity' do
              expect(subject[:quantity]).to eq sell_quantity_less_stash
            end
          end

          context 'it is still profitable when filling far below requested bid' do
            let(:filled_buy_order) do
              JSON.parse(file_fixture('order_24.json').read)
            end
            let(:price) { BigDecimal.new(filled_buy_order['price']) }
            let(:quantity) { BigDecimal.new(filled_buy_order['filled_size']) }
            let(:fee) { BigDecimal.new(filled_buy_order['fill_fees']) }
            let(:buy_costs) { actual_costs('fill_24.json') }
            let(:buy_order) { filled_buy_order }

            before do
              stub_const("BotSettings::PROFIT_INTERVAL", 0.03)
              FlippedTrade.create_from_buy(filled_buy_order)
            end

            it 'returns the expected ask price' do
              expect(subject[:ask]).to eq expected_ask
            end

            it 'returns the expected quantity' do
              expect(subject[:quantity]).to eq sell_quantity_less_stash
            end
          end

          context 'it is unprofitable at the set PROFIT_INTERVAL' do
            let(:filled_buy_order) do
              JSON.parse(file_fixture('order_22.json').read)
            end
            let(:price) { BigDecimal.new(filled_buy_order['price']) }
            let(:quantity) { BigDecimal.new(filled_buy_order['filled_size']) }
            let(:fee) { BigDecimal.new(filled_buy_order['fill_fees']) }
            let(:buy_order) { filled_buy_order }
            let(:cost) { (price * quantity) + fee }
            let(:expected_breakeven_ask) { (cost / quantity).round(2) + 0.01 }
            let(:breakeven_msg) { /Selling at breakeven/ }
            before do
              stub_const("BotSettings::PROFIT_INTERVAL", 0.02)
              allow(Bot).to receive(:log)
              FlippedTrade.create_from_buy(filled_buy_order)
            end

            it 'logs intent to sell at breakeven' do
              subject
              expect(Bot).to have_received(:log).with(breakeven_msg, nil, :warn)
            end

            it 'returns the expected breakeven ask price' do
              expect(subject[:ask]).to eq expected_breakeven_ask
            end

            it 'it does not stash' do
              expect(subject[:quantity]).to eq sell_quantity
            end
          end
        end
      end
    end
  end

  def actual_costs(fill_file_name)
    fill = JSON.parse(file_fixture(fill_file_name).read)
    without_fee = fill.sum do |f|
      BigDecimal.new(f['price']) * BigDecimal.new(f['size'])
    end
    without_fee + fee
  end
end
