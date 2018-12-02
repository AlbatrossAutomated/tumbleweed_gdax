# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sentinel, type: :model do
  describe '.sync_executed_sells' do
    include_examples 'filled sell orders'

    let(:no_sale_log_msg) { 'No sells executed' }

    subject { Sentinel.sync_executed_sells }

    context 'no sells executed' do
      before do
        create_flipped_trades(open_orders)
        allow(Bot).to receive(:log)
      end

      it 'logs that no sell orders have executed' do
        subject
        expect(Bot).to have_received(:log).with(no_sale_log_msg)
      end

      it 'does not call for updating flipped_trade_records' do
        expect(Sentinel).not_to receive(:reconcile_executed_sells)
        subject
      end
    end

    context 'sell orders executed' do
      let(:sold_log_msg) { "#{sold_ids.size} sells executed" }

      before do
        allow(Bot).to receive(:log)
        allow(Request).to receive(:open_orders) { still_open }
        allow_any_instance_of(FlippedTrade).to receive(:reconcile)
      end

      context 'all exchange orders are tracked/persisted' do
        before do
          create_flipped_trades(open_orders)
        end

        it 'calls for updating flipped_trade records' do
          expect(Sentinel).to receive(:reconcile_executed_sells)
          subject
        end

        it 'does not trigger updating pending trade records' do
          FlippedTrade.where(sell_order_id: still_open_ids).each do |ft|
            expect(ft).not_to receive(:reconcile)
          end

          subject
        end

        it 'logs that sell orders executed' do
          subject
          expect(Bot).to have_received(:log).with(sold_log_msg)
        end
      end

      context 'some exchange orders are _not_ tracked/persisted' do
        # In this case, it only gets back open orders that are in the db as
        # pending, so it should do nothing to records. Kind of a silly test, but
        # insurance against changes.

        before do
          create_flipped_trades(still_open)
        end

        it 'ignores the executed sells' do
          subject
          expect(Bot).to have_received(:log).with(no_sale_log_msg)
        end
      end
    end

    context 'a write lag on the exchange to open orders' do
      let(:confirming_sale_log_msg) { 'Possible sales: ' }
      let(:no_sale_log_msg) { 'No sells executed' }
      let(:lagged_order) do
        order = file_fixture('order_3.json').read
        JSON.parse(order).merge('settled' => false).to_json
      end

      before do
        allow(Bot).to receive(:log)
        allow(Request).to receive(:open_orders) { write_lag_still_open }
        allow(Request).to receive(:order) { lagged_order }
        allow_any_instance_of(FlippedTrade).to receive(:reconcile)
      end

      context 'all exchange orders are tracked/persisted' do
        before do
          create_flipped_trades(open_orders)
        end

        it 'calls for updating flipped_trade records' do
          expect(Sentinel).not_to receive(:reconcile_executed_sells)
          subject
        end

        it 'does not trigger updating any trade records' do
          FlippedTrade.where(sell_order_id: write_lag_still_open_ids).each do |ft|
            expect(ft).not_to receive(:reconcile)
          end

          subject
        end

        it 'logs it is confirming a possible sale' do
          subject
          lag_order_id = [JSON.parse(lagged_order)['id']]
          expect(Bot).to have_received(:log).with(confirming_sale_log_msg, lag_order_id)
        end

        it 'logs no sells executed' do
          subject
          expect(Bot).to have_received(:log).with(no_sale_log_msg)
        end
      end
    end
  end

  describe '.reconcile_executed_sells' do
    include_examples 'filled sell orders'

    let(:flipped_trades) { FlippedTrade.where(sell_order_id: sold_ids) }

    before do
      create_flipped_trades(open_orders)
      allow_any_instance_of(FlippedTrade).to receive(:reconcile)
    end

    subject { Sentinel.reconcile_executed_sells(flipped_trades) }

    it 'calls for reconciling sold orders' do
      flipped_trades.each do |ft|
        expect(ft).to receive(:reconcile)

        order = sold.detect { |ord| ord['id'] == ft.sell_order_id }
        allow(RequestUsher).to receive(:execute).and_return(order)

        expect(RequestUsher).to receive(:execute)
          .with('order', ft.sell_order_id)
      end

      subject
    end

    context 'an API write lag results in NotFound' do
      let(:ft) { FlippedTrade.find_by(sell_order_id: '3') }
      let(:flipped_trades) { [ft] }
      let(:not_found) do
        {
          message: 'NotFound'
        }.to_json
      end

      before do
        allow(Request).to receive(:order) { not_found }
        subject
      end

      it 'it does not call for reconciling' do
        expect(ft).to_not receive(:reconcile)
      end
    end
  end

  describe '.check_for_partial_buy' do
    let(:partial_buy) { JSON.parse(file_fixture('order_5.json').read) }
    let(:buy_order_id) { partial_buy['id'] }
    let(:partial_sell) do
      resp = JSON.parse(file_fixture('sell_order.json').read)
      resp['size'] = partial_buy['filled_size']
      resp.to_json
    end

    subject { Sentinel.check_for_partial_buy(buy_order_id) }

    context 'pre-check logging' do
      let(:log_msg) do
        "Checking for partial fill..."
      end

      before do
        allow(Bot).to receive(:log)
        allow(Request).to receive(:sell_order) { partial_sell }
      end

      it 'logs a check for a partially filled buy order' do
        expect(Bot).to receive(:log).with(log_msg)
        subject
      end
    end

    context 'the pending buy order was fully canceled' do
      let(:err_msg) { { message: 'NotFound' }.to_json }
      let(:log_msg) { "No partial fill detected" }

      before do
        allow(Bot).to receive(:log)
        allow(Request).to receive('order') do
          raise Coinbase::Exchange::NotFoundError, err_msg
        end
      end

      it 'logs the order was canceled successfully' do
        expect(Bot).to receive(:log).with(log_msg)
        subject
      end
    end

    context 'the pending buy order partially filled' do
      let(:quantity) { BigDecimal(partial_buy['filled_size']) }
      let(:buy_price) { BigDecimal(partial_buy['price']) }
      let(:buy_fee) { BigDecimal(partial_buy['fill_fees']) }
      let(:buy_cost) { (quantity * buy_price) + buy_fee }
      let(:sell_price) { (buy_price + BotSettings::PROFIT_INTERVAL).round(2) }

      context 'a successful sell order request' do
        before do
          allow(Request).to receive(:sell_order) { partial_sell }
        end

        context 'no buy fee incurred' do
          it 'creates a flipped_trade with the expected fields' do
            subject
            ft = FlippedTrade.last
            expect(ft.buy_price).to eq buy_price
            expect(ft.sell_price).to eq sell_price
            expect(ft.base_currency_purchased).to eq quantity
            expect(ft.buy_fee).to eq buy_fee
            expect(ft.cost).to eq buy_cost
            expect(ft.buy_order_id).to eq partial_buy['id']
            expect(ft.sell_order_id).to eq JSON.parse(partial_sell)['id']
            expect(ft.trade_pair).to eq JSON.parse(partial_sell)['product_id']
          end
        end

        context 'a buy fee was incurred' do
          let(:partial_buy) do
            ord = JSON.parse(file_fixture('order_5.json').read)
            ord.merge('fill_fees' => '0.0123')
          end

          before do
            allow(Request).to receive(:order) { partial_buy.to_json }
          end

          it 'creates a flipped_trade with the expected fields' do
            subject
            ft = FlippedTrade.last
            expect(ft.buy_price).to eq buy_price
            expect(ft.sell_price).to eq sell_price
            expect(ft.base_currency_purchased).to eq quantity
            expect(ft.buy_fee).to eq buy_fee
            expect(ft.cost).to eq buy_cost
            expect(ft.buy_order_id).to eq partial_buy['id']
            expect(ft.sell_order_id).to eq JSON.parse(partial_sell)['id']
            expect(ft.trade_pair).to eq JSON.parse(partial_sell)['product_id']
          end
        end
      end

      context 'an unsuccessful sell order request' do
        let(:err_msg) { { message: 'No way Jose!' }.to_json }

        before do
          allow(Bot).to receive(:log)
          allow(Request).to receive(:sell_order) { err_msg }
        end

        it 'still creates the flipped_trade record' do
          subject
          expect(FlippedTrade.last.buy_order_id).to eq buy_order_id
        end
      end

      context 'the filled amount is < the exchange-allowed min order amount' do
        let(:unsellable) { (ENV['MIN_TRADE_AMT'].to_f - 0.0013).to_s }
        let(:tiny_order) do
          partial_buy.merge('filled_size' => unsellable)
        end
        let(:buy_order_id) { tiny_order['id'] }
        let(:buy_fee) { tiny_order['fill_fees'].to_f }

        context 'really is a partial fill' do
          before do
            allow(Request).to receive(:order) { tiny_order.to_json }
            allow(Request).to receive(:sell_order)
          end

          it 'does not place a sell order' do
            expect(Request).not_to receive(:sell_order)
            subject
          end

          it 'calls for creating an UnsellablePartialBuy record' do
            expect(UnsellablePartialBuy).to receive(:create_from_buy)
              .with(tiny_order)

            subject
          end
        end
      end

      context 'exchange write lags in updating the order as canceled' do
        # filled size from exchange will be '0.000000000'
        let(:cancel_lag) do
          partial_buy.merge('filled_size' => '0.00000000', 'settled' => false).to_json
        end
        let(:cancel_success) do
          { message: 'NotFound' }.to_json
        end

        context 'the order fully cancels' do
          before do
            allow(Request).to receive(:order)
              .and_return(cancel_lag, cancel_success)
            allow(Request).to receive(:sell_order)
          end

          it 'does _not_ create a flipped_trade record' do
            subject
            expect(FlippedTrade.last).to be nil
          end

          it 'does _not_ attempt to place a sell' do
            expect(Request).not_to receive(:sell_order)
            subject
          end
        end

        context 'the order partially fills' do
          before do
            allow(Request).to receive(:order)
              .and_return(cancel_lag, partial_buy.to_json)
            allow(Request).to receive(:sell_order) { partial_sell }
          end

          it 'calls for placing a sell' do
            expect(Request).to receive(:sell_order)
            subject
          end

          it 'creates a flipped_trade record with the expected fields' do
            subject
            ft = FlippedTrade.last
            expect(ft.buy_price).to eq buy_price
            expect(ft.base_currency_purchased).to eq quantity
            expect(ft.buy_order_id).to eq buy_order_id
            expect(ft.sell_order_id).to eq JSON.parse(partial_sell)['id']
            expect(ft.trade_pair).to eq JSON.parse(partial_sell)['product_id']
          end
        end
      end
    end
  end

  # ****************************************************************************
  # Not in use. See sentinel.rb
  # describe '.take_profit' do
  #   let(:price) { '11.00' }
  #   let(:pend_sell1) do
  #     create(:flipped_trade, buy_price: BigDecimal('11.10'))
  #   end
  #   let(:pend_sell2) do
  #     create(:flipped_trade, buy_price: BigDecimal('11.05'))
  #   end
  #   let(:pend_sell3) do
  #     create(:flipped_trade, buy_price: BigDecimal('11.00'))
  #   end
  #   let(:pend_sells) { [pend_sell1, pend_sell2, pend_sell3] }
  #   let(:executed_sell) { create(:flipped_trade, :sell_executed) }
  #   let(:ids) { pend_sells.map(&:id) }
  #   let(:fee) { '0.0' }
  #
  #   before do
  #     pend_sells
  #     executed_sell
  #     subject
  #   end
  #
  #   subject { Sentinel.take_profit(price, fee) }
  #
  #   it 'does not update existing executed sells as consolidated' do
  #     expect(FlippedTrade.find(executed_sell.id).consolidated).to eq false
  #   end
  #
  #   it 'updates consolidated sells as consolidated' do
  #     fts = FlippedTrade.find(ids)
  #     expect(fts.map(&:consolidated).uniq).to eq [true]
  #   end
  #
  #   it 'updates the sell_price to the consolidated price' do
  #     fts = FlippedTrade.find(ids)
  #     expect(fts.map(&:sell_price).uniq).to eq [BigDecimal(price)]
  #   end
  #
  #   it 'updates sell_pending to false' do
  #     fts = FlippedTrade.find(ids)
  #     expect(fts.map(&:sell_pending).uniq).to eq [false]
  #   end
  #
  #   it 'updates the profit of consolidated sells' do
  #     ids.each do |id|
  #       ft = FlippedTrade.find(id)
  #       ft_cost = ft.buy_price * ft.base_currency_purchased
  #       ft_revenue = ft.base_currency_purchased * BigDecimal(price)
  #       expect(ft.quote_currency_profit).to eq BigDecimal(ft_revenue - ft_cost)
  #     end
  #   end
  #
  #   context 'a sell_fee is incurred on the consolidated sell' do
  #     let(:fee) { '0.97856' }
  #     let(:per_ft_fee) { BigDecimal(fee) / pend_sells.count }
  #
  #     it 'updates the sell_fee of consolidated sells equally' do
  #       fts = FlippedTrade.find(ids)
  #       expect(fts.map(&:sell_fee).uniq).to eq [per_ft_fee]
  #     end
  #
  #     it 'updates the cost of consolidated sells' do
  #       pend_sells.each do |ps|
  #         ps_cost = ps.cost
  #         ft_cost = FlippedTrade.find(ps.id).cost
  #         expect(ft_cost - ps_cost).to eq per_ft_fee
  #       end
  #     end
  #
  #     it 'updates the profit of consolidated sells' do
  #       pend_sells.each do |ps|
  #         consolidated_sell_cost = ps.cost + per_ft_fee
  #         ft = FlippedTrade.find(ps.id)
  #         expect(ft.quote_currency_profit).to eq ft.revenue - consolidated_sell_cost
  #       end
  #     end
  #   end
  # end
  # ****************************************************************************
end
