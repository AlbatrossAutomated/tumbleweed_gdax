# frozen_string_literal: true

class QuoteCurrencyProfit
  def self.to_date
    adjustments = LedgerEntry.adjustments.sum(:amount)
    profit_from_trades = FlippedTrade.quote_currency_profit
    adjustments + profit_from_trades
  end

  def self.current_trade_cycle
    FlippedTrade.quote_currency_profit + LedgerEntry.total_adjusted +
      LedgerEntry.total_withdrawn - LedgerEntry.total_reinvested
  end
end
