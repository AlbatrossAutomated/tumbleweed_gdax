# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'record_metrics', type: :rake do
  it { is_expected.to depend_on(:environment) }

  context 'success' do
    it 'calls for creating a performance_metric record' do
      expect(PerformanceMetric).to receive(:record).once
      subject.execute
    end
  end

  context 'failure' do
    let(:err_msg) { 'BOOM!' }
    let(:log_msg) { "ERROR recording metrics: " }

    before do
      allow(PerformanceMetric).to receive(:record) { raise err_msg }
      allow(Bot).to receive(:log)
    end

    it 'logs that something went wrong' do
      subject.execute
      expect(Bot).to have_received(:log).with(log_msg, an_instance_of(RuntimeError), :error)
    end
  end
end
