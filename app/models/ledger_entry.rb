# frozen_string_literal: true

class LedgerEntry < ApplicationRecord
  ADJUSTMENT = 'adjustment'
  WITHDRAWAL = 'withdrawal'
  REINVESTMENT = 'reinvestment'

  CATEGORIES = [ADJUSTMENT, WITHDRAWAL, REINVESTMENT].freeze

  validates :amount, presence: true
  validates :description, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :amount, numericality: { less_than: 0.0 },
                     if: -> { category == WITHDRAWAL }
  validates :amount, numericality: { greater_than: 0.0 },
                     if: -> { category == REINVESTMENT }

  scope :adjustments, -> { where(category: ADJUSTMENT) }
  scope :withdrawals, -> { where(category: WITHDRAWAL) }
  scope :reinvestments, -> { where(category: REINVESTMENT) }

  def self.total_adjusted
    adjustments.sum(:amount)
  end

  def self.total_withdrawn
    withdrawals.sum(:amount)
  end

  def self.total_reinvested
    reinvestments.sum(:amount)
  end
end
