# frozen_string_literal: true

require 'clockwork'

module Clockwork
  handler do |job|
    puts "Running #{job}"
  end

  every(4.hours, 'record_metrics.task') do
    puts `rake record_metrics`
  end
end
