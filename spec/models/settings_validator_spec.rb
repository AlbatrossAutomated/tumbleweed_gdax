# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SettingsValidator, type: :model do
  describe '.validate_quantity' do
    let(:err_msg) do
      "Quantity invalid: Must be greater than exchange's min trade amount"
    end

    before { stub_const("BotSettings::QUANTITY", 0.0001) }

    it "raises a CriticalError" do
      expect { SettingsValidator.validate_quantity }.to raise_error(CriticalError, err_msg)
    end
  end
end
