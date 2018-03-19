# frozen_string_literal: true

RSpec.shared_examples_for 'trader shared' do
  let(:pending_buy_resp) do
    buy = JSON.parse(file_fixture('buy_order.json').read)
    buy.merge('price' => bid.to_s).to_json
  end
  let(:filled_buy_resp) do
    fill = JSON.parse(pending_buy_resp)
    fill.merge('settled' => true,
               'status' => 'done',
               'done_reason' => 'filled',
               'filled_size' => fill['size']).to_json
  end
  let(:scrum_params) { Decide.scrum_params }
  let(:scrum_trigger) { { scrum: true } }
  let(:straddle_trigger) do
    {
      monitor_straddle: true,
      buy_order_id: straddle_order_id,
      bid: straddle_bid
    }
  end
  let(:canceled) { { canceled: true } }
  let(:buy_down) { { buy_down: true } }
  let(:parsed_filled_buy) { JSON.parse(filled_buy_resp) }
  let(:ask_price) { Decide.sell_params(parsed_filled_buy)[:ask] }
  let(:sell_resp) do
    sell_order = JSON.parse(file_fixture('sell_order.json').read)
    sell_order.merge('price' => ask_price.to_f).to_json
  end
  let(:not_found_resp) { { message: 'NotFound' }.to_json }
end
