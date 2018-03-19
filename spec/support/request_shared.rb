# frozen_string_literal: true

RSpec.shared_examples_for 'an exchange API request' do
  it 'calls the expected method' do
    expect_any_instance_of(Coinbase::Exchange::Client)
      .to receive(exchange_client_method).with(exchange_client_arg)

    described_class.send(described_method)
  end
end

RSpec.shared_examples_for 'an exchange API request with a passthrough arg' do
  it 'calls the expected method with the expected arg' do
    expect_any_instance_of(Coinbase::Exchange::Client)
      .to receive(exchange_client_method).with(exchange_client_arg)

    described_class.send(described_method, described_method_arg)
  end
end
