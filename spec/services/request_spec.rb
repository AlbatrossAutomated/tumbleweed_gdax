# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Request do
  let(:fake_uuid) { 'fake-uuid-123' }
  let(:quantity) { 1.324 }
  let(:price) { 15.00 }
  let(:buy_params) do
    {
      bid: price,
      quantity: quantity
    }
  end
  let(:sell_params) do
    {
      ask: price,
      quantity: quantity
    }
  end

  let(:exchange_client_arg) { no_args }

  describe '.quote' do
    let(:exchange_client_method) { :orderbook }
    let(:described_method) { :quote }

    it_behaves_like 'an exchange API request'
  end

  describe '.depth' do
    let(:exchange_client_method) { :orderbook }
    let(:exchange_client_arg) { { level: 2 } }
    let(:described_method) { :depth }

    it_behaves_like 'an exchange API request'
  end

  describe '.order' do
    let(:exchange_client_method) { :order }
    let(:exchange_client_arg) { fake_uuid }
    let(:described_method) { :order }
    let(:described_method_arg) { fake_uuid }

    it_behaves_like 'an exchange API request with a passthrough arg'
  end

  describe '.open_orders' do
    let(:exchange_client_method) { :orders }
    let(:exchange_client_arg) { { status: 'open', product_id: ENV['PRODUCT_ID'] } }
    let(:described_method) { :open_orders }

    it_behaves_like 'an exchange API request'
  end

  describe '.filled_order' do
    let(:exchange_client_method) { :fills }
    let(:exchange_client_arg) { { order_id: fake_uuid } }
    let(:described_method) { :filled_order }
    let(:described_method_arg) { fake_uuid }

    it_behaves_like 'an exchange API request with a passthrough arg'
  end

  describe '.funds' do
    let(:exchange_client_method) { :accounts }
    let(:described_method) { :funds }

    it_behaves_like 'an exchange API request'
  end

  describe '.sell_order' do
    it 'calls the expected method with the expected arg' do
      expect_any_instance_of(Coinbase::Exchange::Client)
        .to receive(:sell).with(sell_params[:quantity], sell_params[:ask])
      Request.sell_order(sell_params)
    end
  end

  describe '.buy_order' do
    let(:quant) { buy_params[:quantity] }
    let(:bid) { buy_params[:bid] }

    it 'calls the expected method with the expected args' do
      expect_any_instance_of(Coinbase::Exchange::Client)
        .to receive(:buy).with(quant, bid, stp: 'cn')
      Request.buy_order(buy_params)
    end
  end

  describe '.cancel_order' do
    let(:exchange_client_method) { :cancel }
    let(:exchange_client_arg) { fake_uuid }
    let(:described_method) { :cancel_order }
    let(:described_method_arg) { fake_uuid }

    it_behaves_like 'an exchange API request with a passthrough arg'
  end

  describe '.products' do
    let(:exchange_client_method) { :products }
    let(:described_method) { :products }

    it_behaves_like 'an exchange API request'
  end

  describe '.products' do
    let(:exchange_client_method) { :currencies }
    let(:described_method) { :currencies }

    it_behaves_like 'an exchange API request'
  end
end
