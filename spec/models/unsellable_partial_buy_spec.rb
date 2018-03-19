# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UnsellablePartialBuy, type: :model do
  describe 'validations' do
    it { should validate_numericality_of(:base_currency_purchased).is_greater_than(0.0) }
  end

  describe '.create_from_buy' do
    let(:partial_buy) do
      ord = JSON.parse(file_fixture('order_5.json').read)
      ord.merge('fill_fees' => '0.0123')
    end
    let(:unsellable) { (ENV['MIN_TRADE_AMT'].to_f - 0.0013).to_s }
    let(:tiny_order) do
      partial_buy.merge('filled_size' => unsellable)
    end
    let(:buy_order_id) { tiny_order['id'] }
    let(:buy_fee) { tiny_order['fill_fees'].to_f }
    let(:price) { tiny_order['price'].to_f }

    it 'creates a record with the expected fields' do
      pb = UnsellablePartialBuy.create_from_buy(tiny_order)

      expect(pb.base_currency_purchased.to_f).to eq unsellable.to_f
      expect(pb.buy_price).to eq price
      expect(pb.buy_order_id).to eq buy_order_id
      expect(pb.buy_fee).to eq buy_fee
      expect(pb.trade_pair).to eq ENV['PRODUCT_ID']
    end
  end
end
