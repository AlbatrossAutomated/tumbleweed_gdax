# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Trader, type: :model do
  include_examples 'trader shared'

  describe '.begin_trade_cycle' do
    let(:bid) { scrum_params[:bid] }

    subject { Trader.begin_trade_cycle }

    before do
      allow(Bot).to receive(:log)
      allow(Request).to receive(:buy_order) { pending_buy_resp }
    end

    context 'before buy order monitoring' do
      before do
        allow(Trader).to receive(:loop).and_yield
        allow(Trader).to receive(:monitor_scrum) do
          { monitoring: 'psyche!' }
        end
      end

      context 'successful order placement' do
        after { subject }

        it 'calls for syncing executed' do
          expect(Sentinel).to receive(:sync_executed_sells)
        end

        it 'calls for validating settings' do
          allow(SettingsValidator).to receive(:validate)
          expect(SettingsValidator).to receive(:validate)
        end

        it 'calls for checking affordability of a buy' do
          allow(Decide).to receive(:affordable?)
          expect(Decide).to receive(:affordable?).with(scrum_params)
        end

        it 'calls for placing a buy order' do
          expect(Request).to receive(:buy_order).with(scrum_params)
        end

        it 'logs the buy order response' do
          msg = "SCRUM placed. Resp:"
          expect(Bot).to receive(:log).with(msg, JSON.parse(pending_buy_resp))
        end

        it 'monitors the pending buy order' do
          id = JSON.parse(pending_buy_resp)['id']
          expect(Trader).to receive(:monitor_scrum).with(id, scrum_params[:bid])
        end
      end
    end

    context 'while monitoring pending buy order' do
      context 'order executed' do
        let(:straddle_order_id) { '6' }
        let(:straddle_bid) { Decide.scrum_params[:bid] }

        before do
          allow(Trader).to receive(:loop).and_yield
          allow(Trader).to receive(:monitor_scrum) { buy_down }
          allow(Trader).to receive(:monitor_straddle)
          allow(Trader).to receive(:place_buy_down) { straddle_trigger }
        end

        it 'calls for placing a buy_down order' do
          expect(Trader).to receive(:place_buy_down)
          subject
        end

        it 'calls for monitoring the straddle positions' do
          expect(Trader).to receive(:monitor_straddle)
          subject
        end
      end

      context 'scrum bid is no longer the highest' do
        before do
          allow(Trader).to receive(:loop).and_yield.and_yield
          allow(Trader).to receive(:monitor_scrum) { canceled }
        end

        it 'calls for bidding again' do
          expect(Request).to receive(:buy_order).exactly(:twice)
          subject
        end
      end
    end
  end

  describe '.maybe_idle' do
    let(:bid) { 23.27 }

    subject { Trader.maybe_idle(bid) }

    after { subject }

    before do
      allow(Trader).to receive(:loop).and_yield.and_yield
    end

    context 'the upcoming buy order is affordable' do
      before do
        allow(Decide).to receive(:affordable?) { true }
      end

      it 'does not idle' do
        expect(Decide).to receive(:affordable?).once
      end
    end

    context 'the upcoming buy order is unaffordable' do
      before do
        allow(Decide).to receive(:affordable?) { false }
      end

      it 'idles' do
        expect(Decide).to receive(:affordable?).exactly(:twice)
      end
    end
  end

  describe '.monitor_scrum' do
    let(:bid) { scrum_params[:bid] }
    let(:scrum_id) { JSON.parse(pending_buy_resp)['id'] }
    let(:flip_count) do
      create_list(:flipped_trade, 3, :sell_executed)
      FlippedTrade.count
    end
    let(:log_msg) { "Trades flipped: #{flip_count}" }

    subject { Trader.monitor_scrum(scrum_id, scrum_params[:bid]) }

    it 'logs the number of trades flipped' do
      allow(Trader).to receive(:loop).and_yield
      allow(Bot).to receive(:log)
      expect(Bot).to receive(:log).with(log_msg)
      subject
    end

    context 'the order is the best bid' do
      before do
        allow(Trader).to receive(:loop).and_yield.and_yield
        allow(Request).to receive(:order) { pending_buy_resp }
      end

      it 'continues to monitor' do
        expect(Request).to receive(:order).with(scrum_id).exactly(:twice)
        subject
      end
    end

    context 'the order is outbid' do
      let!(:over_bid) { (scrum_params[:bid] + 0.01).round(2) }
      let(:outbid_quote) do
        quote = JSON.parse(file_fixture('quote.json').read)
        quote['bids'][0][0] = over_bid
        quote.to_json
      end

      before do
        allow(Request).to receive(:quote) { outbid_quote }
        allow(Request).to receive(:order) { not_found_resp }
      end

      it 'cancels the scrum order' do
        expect(subject).to eq canceled
      end
    end

    context 'the order executes' do
      describe '.handle_filled_buy' do
        let(:parsed_resp) { parsed_filled_buy }
        let(:price) { BigDecimal(parsed_resp['price']) }
        let(:quantity) { BigDecimal(parsed_resp['size']) }
        let(:fee) { BigDecimal(parsed_resp['fill_fees']) }
        let(:cost) { (price * quantity) + fee }
        let(:consecutive_buys_count) { 0 }

        before do
          Trader.consecutive_buys = consecutive_buys_count
          allow(Request).to receive(:order) { filled_buy_resp }
          allow(Request).to receive(:sell_order) { sell_resp }
          allow(Trader).to receive(:exchange_finalized) { parsed_resp }
        end

        it 'adds to the consecutive buy count' do
          subject
          expect(Trader.consecutive_buys).to eq consecutive_buys_count + 1
        end

        it 'checks the fill_size is accurate' do
          expect(Trader).to receive(:exchange_finalized)
          subject
        end

        it 'creates a flipped_trade with the expected fields' do
          subject
          ft = FlippedTrade.last
          expect(ft.buy_price).to eq price
          expect(ft.base_currency_purchased).to eq quantity
          expect(ft.buy_fee).to eq fee
          expect(ft.cost).to eq cost
          expect(ft.buy_order_id).to eq parsed_resp['id']
          expect(ft.trade_pair).to eq parsed_resp['product_id']
        end

        it 'calls for placing a corresponding sell' do
          expect(Request).to receive(:sell_order)
          subject
        end

        it 'returns a buy_down status' do
          expect(subject).to eq buy_down
        end
      end
    end
  end

  describe '.exchange_finalized' do
    let(:bid) { scrum_params[:bid] }
    let(:inaccurate_resp) do
      order = JSON.parse(filled_buy_resp)
      filled_size = order['filled_size']
      inaccurate = order.merge('filled_size' => BigDecimal(filled_size) * 0.10)
      inaccurate.to_json
    end
    let(:inaccurate_parsed) { JSON.parse(inaccurate_resp) }

    before do
      allow(Trader).to receive(:loop).and_yield.and_yield.and_yield
      allow(Request).to receive(:order).and_return(inaccurate_resp, filled_buy_resp)
    end

    subject { Trader.exchange_finalized(inaccurate_parsed) }

    it "polls the endpoint until 'filled_size' is accurate" do
      expect(Request).to receive(:order).exactly(:twice)
      subject
    end

    it 'returns the exchange finalized order' do
      expect(subject).to eq JSON.parse(filled_buy_resp)
    end
  end

  describe '.place_sell' do
    let(:bid) { JSON.parse(file_fixture('buy_order.json').read)['price'] }
    let(:flipped_trade) do
      create(:flipped_trade, :buy_executed,
             buy_price: BigDecimal(parsed_filled_buy['price']),
             buy_fee: BigDecimal(parsed_filled_buy['fill_fees']),
             base_currency_purchased: BigDecimal(parsed_filled_buy['filled_size']),
             buy_order_id: parsed_filled_buy['id'])
    end
    let(:buy_price) { parsed_filled_buy['price'].to_f }
    let(:sell_params) { Decide.sell_params(parsed_filled_buy) }

    subject { Trader.place_sell(flipped_trade, parsed_filled_buy) }

    context 'successful exchange request' do
      before do
        allow(Request).to receive(:sell_order) { sell_resp }
      end

      it 'calls for placing a sell order with the expected values' do
        expect(Request).to receive(:sell_order).with(sell_params)
        subject
      end

      it 'updates the flipped_trade record with the expected fields' do
        subject
        ft = FlippedTrade.last
        expect(ft.sell_price).to eq ask_price
        expect(ft.sell_order_id).to eq JSON.parse(sell_resp)['id']
      end
    end
  end

  describe '.place_buy_down' do
    let(:pevious_bid) { 12.00 }
    let(:buy_down_bid) { Decide.buy_down_params(pevious_bid)[:bid] }
    let(:bid) { buy_down_bid }
    let(:buy_down_resp) { pending_buy_resp }

    subject { Trader.place_buy_down(pevious_bid) }

    before do
      Trader.consecutive_buys = 2
      allow(Request).to receive(:buy_order) { buy_down_resp }
      allow(Decide).to receive(:affordable?) { true }
      allow(Bot).to receive(:log)
    end

    context 'no trade zone is triggered' do
      before do
        stub_const("BotSettings::CHILL_PARAMS", consecutive_buys: 2, wait_time: 1)
        allow(Trader).to receive(:chill)
      end

      it 'calls for a trading pause' do
        expect(Trader).to receive(:chill)
        subject
      end
    end

    it 'checks affordability of the buy_down' do
      expect(Decide).to receive(:affordable?)
      subject
    end

    context 'buy_down order placement' do
      context 'success' do
        let(:log_msg) do
          "BUY DOWN placed. Response: "
        end
        let(:straddle_order_id) { JSON.parse(buy_down_resp)['id'] }
        let(:straddle_bid) { buy_down_bid }

        it 'logs details' do
          expect(Bot).to receive(:log).with(log_msg, JSON.parse(buy_down_resp))
          subject
        end

        it 'calls for placing a buy' do
          expect(Request).to receive(:buy_order)
          subject
        end

        it 'returns a straddle monitoring trigger value' do
          expect(subject).to eq straddle_trigger
        end
      end
    end
  end

  describe '.chill' do
    before do
      allow(Trader).to receive(:loop).and_yield.and_yield
    end

    subject { Trader.chill }

    context 'no un-chill criteria are met' do
      before do
        allow(Trader).to receive(:sells_executed?) { false }
      end

      it 'continues to chill' do
        expect(Trader).to receive(:sells_executed?).exactly(:twice)
        expect(Trader).to receive(:wait_time_expired?).exactly(:twice)
        subject
      end
    end

    context 'un-chill criteria are met' do
      context 'a sell order executes' do
        before do
          allow(Trader).to receive(:sells_executed?) { true }
        end

        it 'trades again' do
          expect(Trader).to receive(:sells_executed?).once
          expect(subject).to eq scrum_trigger
        end
      end

      context 'wait time expires' do
        before do
          allow(Trader).to receive(:wait_time_expired?) { true }
        end

        it 'trades again' do
          expect(Trader).to receive(:wait_time_expired?).once
          expect(subject).to eq scrum_trigger
        end
      end
    end
  end

  describe '.place_rebuy' do
    include_examples 'pending sells'

    let(:previous_bid) { 11.21 }
    let(:rebuy_bid) { Decide.rebuy_params[:bid] }
    let(:bid) { rebuy_bid }
    let(:rebuy_resp) { pending_buy_resp }

    subject { Trader.place_rebuy }

    before do
      allow(Request).to receive(:buy_order) { rebuy_resp }
      allow(Decide).to receive(:affordable?) { true }
      allow(Bot).to receive(:log)
    end

    it 'checks affordability of the rebuy' do
      expect(Decide).to receive(:affordable?)
      subject
    end

    context 'rebuy order placement' do
      context 'success' do
        let(:log_msg) { "REBUY placed. Response: " }
        let(:straddle_order_id) { JSON.parse(rebuy_resp)['id'] }
        let(:straddle_bid) { rebuy_bid }

        it 'logs details' do
          expect(Bot).to receive(:log).with(log_msg, JSON.parse(rebuy_resp))
          subject
        end

        it 'calls for placing a buy' do
          expect(Request).to receive(:buy_order)
          subject
        end

        it 'returns a straddle monitoring trigger value' do
          expect(subject).to eq straddle_trigger
        end
      end
    end
  end

  describe '.monitor_straddle' do
    include_examples 'filled sell orders'

    let(:buy_pend) do
      JSON.parse(open_orders).detect { |ord| ord['side'] == 'buy' }
    end
    let(:buy_pend_id) { buy_pend['id'] }
    let(:bid) { buy_pend['price'].to_f.round(2) }

    subject { Trader.monitor_straddle(buy_pend_id, bid) }

    before do
      create_flipped_trades(open_orders)
      allow(Trader).to receive(:loop).and_yield
      allow(Bot).to receive(:log)
      Trader.consecutive_buys = 1
    end

    context 'neither buy or sell(s) execute' do
      before do
        allow(Trader).to receive(:loop).and_yield.and_yield
        allow(Trader).to receive(:cancel_buy)
        allow(Trader).to receive(:place_sell)
      end

      it 'continues to monitor' do
        expect(Trader).not_to receive(:cancel_buy)
        expect(Trader).not_to receive(:place_sell)
        subject
      end
    end

    context 'a self-trade event occurs' do
      let(:self_trade_buy) do
        buy_pend.merge('settled' => true, 'done_reason' => 'canceled')
      end
      let(:msg) { "POSSIBLE STP for buy_order:" }
      let(:api_resp) { self_trade_buy }

      before do
        allow(Request).to receive(:order) { self_trade_buy.to_json }
      end

      it 'logs a possible self trade event occured' do
        expect(Bot).to receive(:log).with(msg, api_resp, :warn)
        subject
      end
    end

    context 'the buy order fills' do
      let(:buy_exe_resp) do
        buy_pend.merge('settled' => true,
                       'done_reason' => 'filled',
                       'filled_size' => buy_pend['size'],
                       'status' => 'done').to_json
      end
      let(:buy_exe_id) { JSON.parse(buy_exe_resp)['id'] }
      let(:buy_exe_msg) { "BUY DOWN FILLED!!" }
      let(:buy_down_bid) { Decide.buy_down_params(bid) }
      let(:buy_down_resp) do
        JSON.parse(pending_buy_resp).merge('price' => buy_down_bid).to_json
      end
      let(:ask_price) { Decide.sell_params(JSON.parse(buy_exe_resp))[:ask] }
      let(:sell_resp) do
        sell_order = JSON.parse(file_fixture('sell_order.json').read)
        sell_order.merge('price' => ask_price.to_f).to_json
      end
      let(:sell_id) { JSON.parse(sell_resp)['id'] }
      let(:straddle_order_id) { JSON.parse(buy_down_resp)['id'] }
      let(:straddle_bid) { buy_down_bid }

      before do
        allow(Request).to receive(:sell_order) { sell_resp }
        allow(Request).to receive(:buy_order) { buy_down_resp }
        allow(Request).to receive(:order) { buy_exe_resp }
      end

      it 'logs the buy order filled' do
        expect(Bot).to receive(:log).with(buy_exe_msg)
        subject
      end

      it 'creates the flipped_trade record' do
        subject
        ft = FlippedTrade.last
        expect(ft.buy_order_id).to eq buy_exe_id
        expect(ft.sell_order_id).to eq sell_id
      end

      it 'calls for placing the corresponding sell' do
        expect(Trader).to receive(:place_sell)
        subject
      end

      it 'calls for placing a buy_down' do
        allow(Trader).to receive(:place_buy_down) { straddle_trigger }
        subject
        expect(Trader).to have_received(:place_buy_down)
      end

      it 'monitors the new straddle' do
        allow(Trader).to receive(:loop).and_yield.and_yield
        expect(Trader).to receive(:sells_executed?).exactly(:twice)
        subject
      end
    end

    context 'sell order(s) fills' do
      let(:sell_exe_msg) { "SELL(s) FILLED!!" }
      let(:rebuy_bid) { Decide.rebuy_params[:bid] }
      let(:rebuy_resp) do
        JSON.parse(pending_buy_resp).merge('price' => rebuy_bid).to_json
      end
      let(:straddle_order_id) { JSON.parse(rebuy_resp)['id'] }
      let(:straddle_bid) { rebuy_bid }

      before do
        allow(Request).to receive(:open_orders) { still_open }
        allow(Bot).to receive(:log)
        allow(Trader).to receive(:cancel_buy) { canceled }
        allow(Request).to receive(:buy_order) { rebuy_resp }
      end

      context 'some pending sells executed' do
        let(:sell_stats) do
          {
            sold: sold.size,
            pending: still_open.size,
            highest_sold: highest_sold
          }
        end

        it 'logs the sell order(s) execution' do
          expect(Bot).to receive(:log).with(sell_exe_msg)
          subject
        end

        it 'cancels the pending buy' do
          expect(Trader).to receive(:cancel_buy)
          subject
        end

        it 'places a rebuy' do
          allow(Trader).to receive(:place_rebuy) { straddle_trigger }
          expect(Trader).to receive(:place_rebuy)
          subject
        end

        it 'monitors the new straddle' do
          allow(Trader).to receive(:loop).and_yield.and_yield
          allow(Trader).to receive(:sell_side_stats) { sell_stats }
          expect(Trader).to receive(:sell_side_stats).exactly(:twice)
          subject
        end

        context 'order backfilling' do
          let(:highest_sold) { 10.00 }
          let(:sell_stats) do
            {
              sold: 2,
              pending: 11,
              highest_sold: highest_sold
            }
          end

          before do
            allow(Trader).to receive(:sell_side_stats) { sell_stats }
            allow(FlippedTrade).to receive(:lowest_ask) { lowest_ask }
          end

          context 'larger than BDI price gap between highest executed sell and lowest ask' do
            let(:lowest_ask) { highest_sold + (BotSettings::BUY_DOWN_INTERVAL * 1.2) }

            context 'when set to false' do
              it 'initiates a new trade cycle' do
                expect(subject).to eq scrum_trigger
              end
            end

            context 'when set to true' do
              before do
                stub_const("BotSettings::ORDER_BACKFILLING", true)
              end

              it 'calls for placing a rebuy' do
                allow(Trader).to receive(:straddle_rebuy)
                expect(Trader).to receive(:straddle_rebuy)
                subject
              end
            end
          end

          context 'price gap between highest executed sell and lowest ask is BDI or less' do
            let(:lowest_ask) { highest_sold + BotSettings::BUY_DOWN_INTERVAL }

            context 'when set to false' do
              it 'calls for placing a rebuy' do
                allow(Trader).to receive(:straddle_rebuy)
                expect(Trader).to receive(:straddle_rebuy)
                subject
              end
            end

            context 'when set to true' do
              before do
                stub_const("BotSettings::ORDER_BACKFILLING", true)
              end

              it 'calls for placing a rebuy' do
                allow(Trader).to receive(:straddle_rebuy)
                expect(Trader).to receive(:straddle_rebuy)
                subject
              end
            end
          end
        end
      end

      context 'all pending sells executed' do
        let(:all_sells_exe) do
          {
            sold: 13,
            pending: 0,
            highest_sold: 23.67
          }
        end

        before do
          allow(Trader).to receive(:sell_side_stats) { all_sells_exe }
        end

        it 'initiates a new trade cycle' do
          expect(subject).to eq scrum_trigger
        end
      end
    end
  end

  describe '.cancel_buy' do
    let(:pending_buy) { JSON.parse(file_fixture('order_4.json').read) }
    let(:filled_buy) do
      pending_buy.merge('settled' => true,
                        'done_reason' => 'filled',
                        'filled_size' => pending_buy['size'],
                        'status' => 'done').to_json
    end
    let(:bid) { pending_buy['price'] }
    let(:id) { pending_buy['id'] }

    before do
      allow(Bot).to receive(:log)
    end

    subject { Trader.cancel_buy(id) }

    context 'success' do
      let(:success_msg) { "SUCCESS canceling." }
      before do
        allow(Request).to receive(:order) { not_found_resp }
      end

      it 'logs a cancel message' do
        expect(Bot).to receive(:log).with(success_msg)
        subject
      end

      it 'calls for a partial fill check' do
        expect(Sentinel).to receive(:check_for_partial_buy).with(id)
        subject
      end

      it 'returns the canceled hash' do
        expect(subject).to eq canceled
      end
    end

    context 'failure' do
      context 'the order executed before canceling' do
        let(:done_msg) { "FAILURE canceling - Order already done" }
        let(:done_resp) { { message: 'Order already done' }.to_json }

        before do
          allow(Request).to receive(:cancel_order) { done_resp }
          allow(Request).to receive(:order) { filled_buy }
          allow(Trader).to receive(:place_sell) { true }
        end

        it 'logs an already done message' do
          expect(Bot).to receive(:log).with(done_msg)
          subject
        end

        it 'creates a flipped_trade record' do
          subject
          expect(FlippedTrade.last.buy_order_id).to eq id
        end

        it 'places the associated sell' do
          expect(Trader).to receive(:place_sell)
          subject
        end

        it 'returns a buy down trigger' do
          expect(subject).to eq buy_down
        end
      end

      context 'the order executed before canceling, but API lags to write' do
        let(:done_msg) { "FAILURE canceling - Order already done" }
        let(:done_resp) { { message: 'Order already done' }.to_json }
        let(:still_pending) { file_fixture('order_4.json').read }

        before do
          allow(Request).to receive(:cancel_order) { done_resp }
          allow(Request).to receive(:order)
            .and_return(still_pending, filled_buy)
        end

        it 'retries the order until it is settled' do
          expect(Request).to receive(:order).twice
          subject
        end
      end

      context 'the exchange responds with NotFound' do
        let(:retries) { BotSettings::CANCEL_RETRIES }

        before do
          allow(Request).to receive(:cancel_order) { not_found_resp }
        end

        it 'retries canceling the expected number of times' do
          expect(Request).to receive(:cancel_order).exactly(retries).times
          subject
        end
      end
    end
  end

  describe '.sell_side_stats' do
    include_examples 'filled sell orders'

    subject { Trader.sell_side_stats }

    it 'logs price positions' do
      expect(Trader).to receive(:log_price_positions)
      subject
    end

    context 'no sells executed' do
      let(:log_msg) do
        "PENDING SELLS: #{sell_orders.size}"
      end
      let(:expected) do
        {
          sold: 0,
          pending: sell_orders.size,
          highest_sold: 'N/A'
        }
      end

      before { create_flipped_trades(open_orders) }

      it 'logs the stats' do
        allow(Bot).to receive(:log)
        expect(Bot).to receive(:log).with(log_msg)
        subject
      end

      it 'returns the expected stats' do
        expect(subject).to eq expected
      end
    end

    context 'sells executed' do
      let(:expected) do
        {
          sold: sold_ids.size,
          pending: sell_orders.size - sold_ids.size,
          highest_sold: highest_sold
        }
      end

      before do
        create_flipped_trades(open_orders)
        allow(Request).to receive(:open_orders) { still_open }
      end

      it 'calls for reconciling the executed sells' do
        expect(Sentinel).to receive(:reconcile_executed_sells)
        subject
      end

      it 'returns the expected stats' do
        expect(subject).to eq expected
      end
    end

    context 'all sells executed' do
      let(:fills) { JSON.parse(open_orders).select { |ord| ord['id'] == ('2' || '3') } }
      let(:sold_count) { fills.size }

      before { create_flipped_trades(fills.to_json) }

      context 'and are tracked' do
        let(:all_filled) { [].to_json }

        let(:expected) do
          {
            sold: sold_count,
            pending: 0,
            highest_sold: FlippedTrade.all.max_by(&:sell_price).sell_price
          }
        end

        it 'sets pending to zero' do
          allow(Request).to receive(:open_orders) { all_filled }
          expect(subject).to eq expected
        end
      end

      context 'but not all are tracked' do
        let(:untracked) { file_fixture('untracked_orders.json').read }

        let(:expected) do
          {
            sold: sold_count,
            pending: 0,
            highest_sold: FlippedTrade.all.max_by(&:sell_price).sell_price
          }
        end

        it 'sets pending to zero' do
          allow(Request).to receive(:open_orders) { untracked }
          expect(subject).to eq expected
        end
      end
    end
  end

  describe '.log_price_positions' do
    include_examples 'filled sell orders'

    let(:orders) { JSON.parse(open_orders) }
    let(:buy_order) do
      orders.detect { |ord| ord['side'] == 'buy' }
    end
    let(:sell_orders) do
      orders.select { |ord| ord['side'] == 'sell' }
    end
    let(:buy_price) { [buy_order['price'].to_f] }
    let(:sell_prices) do
      sell_orders.map { |ord| ord['price'].to_f }
    end
    let(:quote_currency_profit_msg) { /QUOTE CURRENCY PROFIT/ }
    let(:position_msg) do
      "Buy: #{buy_price}. Sell(s): #{sell_prices}"
    end

    subject { Trader.log_price_positions(orders) }

    before { allow(Bot).to receive(:log) }

    it 'logs the current quote currency profit'
    # Removed - query takes too long
    # it 'logs the current quote currency profit' do
    #   expect(Bot).to receive(:log).with(quote_currency_profit_msg)
    #   subject
    # end

    it 'logs the buy and sell side price positions' do
      expect(Bot).to receive(:log).with(position_msg)
      subject
    end
  end
end
