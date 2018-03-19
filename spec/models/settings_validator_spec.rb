# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SettingsValidator, type: :model do
  describe '.validate_coverage' do
    let(:err_msg) do
      "Coverage invalid: Must be in the range 0.01 - 1.0"
    end

    before { stub_const("BotSettings::COVERAGE", 1.1) }

    it "raises a CriticalError" do
      expect { SettingsValidator.validate_coverage }.to raise_error(CriticalError, err_msg)
    end
  end

  describe '.validate_base_currency_stash' do
    let(:err_msg) do
      "Base currency stash invalid: Must be in the range 0.0 - 1.0"
    end

    before { stub_const("BotSettings::BASE_CURRENCY_STASH", 1.1) }

    it "raises a CriticalError" do
      expect { SettingsValidator.validate_base_currency_stash }.to raise_error(CriticalError, err_msg)
    end
  end
end
