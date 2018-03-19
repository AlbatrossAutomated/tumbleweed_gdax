# frozen_string_literal: true

require 'rails_helper'

RSpec.describe LedgerEntry, category: :model do
  describe 'validations' do
    it { should validate_presence_of(:amount) }
    it { should validate_presence_of(:description) }
    it { should validate_presence_of(:category) }

    it 'validates the category value' do
      should validate_inclusion_of(:category).in_array(LedgerEntry::CATEGORIES)
    end

    it 'disallows an invalid category value' do
      entry = build(:ledger_entry, category: 'foo')
      expect(entry.valid?).to be false
    end

    context 'amount' do
      it 'allows positive values when category is adjustment' do
        entry = build(:ledger_entry, amount: BigDecimal.new('1.0'))
        expect(entry.valid?).to be true
      end

      it 'disallows positive values for withdrawals' do
        attribs = {
          category: LedgerEntry::WITHDRAWAL,
          amount: BigDecimal.new('1.0')
        }
        entry = build(:ledger_entry, attribs)

        expect(entry.valid?).to be false
      end

      it 'disallows negative values for reinvestments' do
        attribs = {
          category: LedgerEntry::REINVESTMENT,
          amount: BigDecimal.new('-1.0')
        }
        entry = build(:ledger_entry, attribs)

        expect(entry.valid?).to be false
      end
    end
  end
end
