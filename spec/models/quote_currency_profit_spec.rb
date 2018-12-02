# frozen_string_literal: true

require 'rails_helper'

RSpec.describe QuoteCurrencyProfit, category: :model do
  let(:trades) { create_list(:flipped_trade, 5, :sell_executed) }
  let(:trade_profit) { trades.sum(&:quote_currency_profit) }
  let(:entry_amt) { trade_profit * 0.20 }

  before { trade_profit }

  describe '.to_date' do
    let(:adjustment) do
      create(:ledger_entry, amount: BigDecimal(entry_amt))
    end
    let(:expected_amt) do
      trade_profit + adjustment.amount
    end

    before { adjustment }

    it 'returns profit to date' do
      expect(QuoteCurrencyProfit.to_date).to eq expected_amt
    end
  end

  describe '.current_trade_cycle' do
    let(:adjust) do
      attribs = {
        category: LedgerEntry::ADJUSTMENT,
        amount: trade_profit,
        description: "an adjustment"
      }
      create(:ledger_entry, attribs)
    end
    let(:withdraw) do
      attribs = {
        category: LedgerEntry::WITHDRAWAL,
        amount: -(trade_profit - entry_amt),
        description: "a withdrawal"
      }
      create(:ledger_entry, attribs)
    end
    let(:reinvest) do
      attribs = {
        category: LedgerEntry::REINVESTMENT,
        amount: trade_profit,
        description: "a reinvestment"
      }
      create(:ledger_entry, attribs)
    end

    context 'adjustment' do
      before { adjust }

      it 'returns profit for current trade cycle' do
        expect(QuoteCurrencyProfit.current_trade_cycle).to eq trade_profit * 2
      end
    end

    context 'withdrawal' do
      before { withdraw }

      it 'returns profit for current trade cycle' do
        expect(QuoteCurrencyProfit.current_trade_cycle).to eq entry_amt
      end
    end

    context 'reinvestment' do
      before { reinvest }

      it 'returns profit for current trade cycle' do
        expect(QuoteCurrencyProfit.current_trade_cycle).to eq 0.0
      end
    end

    context 'all categories' do
      let!(:expected_amt) do
        trade_profit + adjust.amount + withdraw.amount - reinvest.amount
      end

      it 'returns profit for current trade cycle' do
        expect(QuoteCurrencyProfit.current_trade_cycle).to eq expected_amt
      end
    end
  end
end
