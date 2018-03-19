# frozen_string_literal: true

class BotSettings
  COVERAGE = 0.30
  BUY_DOWN_INTERVAL = 0.25
  PROFIT_INTERVAL = 0.25
  PRINT_MANTRA = false
  HOARD_QUOTE_PROFITS = true
  BASE_CURRENCY_STASH = 0.0
  ORDER_BACKFILLING = false
  CANCEL_RETRIES = 10
  RESERVE = 0.0
  CHILL_PARAMS = { consecutive_buys: 3, wait_time: 1 }.freeze # wait_time in minutes
end
