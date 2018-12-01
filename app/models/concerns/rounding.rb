module Rounding
  extend ActiveSupport::Concern

  def qc_tick_rounded(value)
    value.round(ENV['QC_TICK_LENGTH'].to_i)
  end

  def bc_tick_rounded(value)
    value.round(ENV['BC_TICK_LENGTH'].to_i)
  end
end
