# frozen_string_literal: true

class SettingsValidator
  class << self
    def validate
      validate_quantity
    end

    def validate_quantity
      return if BotSettings::QUANTITY >= ENV['MIN_TRADE_AMT'].to_f

      msg = "Quantity invalid: Must be greater than exchange's min trade amount"
      raise CriticalError, msg
    end
  end
end
