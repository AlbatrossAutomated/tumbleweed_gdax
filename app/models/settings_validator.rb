# frozen_string_literal: true

class SettingsValidator
  class << self
    def validate
      validate_coverage
      validate_base_currency_stash
    end

    def validate_coverage
      return if BotSettings::COVERAGE.between?(0.01, 1.0)
      msg = "Coverage invalid: Must be in the range 0.01 - 1.0"
      raise CriticalError, msg
    end

    def validate_base_currency_stash
      return if BotSettings::BASE_CURRENCY_STASH.between?(0.0, 1.0)
      msg = "Base currency stash invalid: Must be in the range 0.0 - 1.0"
      raise CriticalError, msg
    end
  end
end
