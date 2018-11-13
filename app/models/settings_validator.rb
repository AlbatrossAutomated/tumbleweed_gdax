# frozen_string_literal: true

class SettingsValidator
  class << self
    def validate
      validate_quantity
      validate_base_currency_stash
    end

    def validate_quantity
      return if BotSettings::QUANTITY >= ENV['MIN_TRADE_AMT'].to_f
      msg = "Quantity invalid: Must be greater than exchange's min trade amount"
      raise CriticalError, msg
    end

    def validate_base_currency_stash
      return if BotSettings::BC_STASH.between?(0.0, 1.0)
      msg = "Base currency stash invalid: Must be in the range 0.0 - 1.0"
      raise CriticalError, msg
    end
  end
end
