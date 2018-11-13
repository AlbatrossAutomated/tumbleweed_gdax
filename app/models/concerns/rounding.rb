module Rounding
  extend ActiveSupport::Concern

  def round_to_qc_tick(value)
    value.round(ENV['QC_TICK_LENGTH'].to_i)
  end

  def round_to_bc_tick(value)
    value.round(ENV['BC_TICK_LENGTH'].to_i)
  end
end
