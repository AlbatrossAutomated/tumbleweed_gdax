# frozen_string_literal: true

desc 'creates performance metrics records at set interval'
task record_metrics: :environment do
  Bot.log('Due to throttling, recording metrics too frequently _may_ impact performance', nil, :warn)
  Bot.log('Recording Metrics ...')
  begin
    PerformanceMetric.record
  rescue StandardError => e
    Bot.log("ERROR recording metrics: ", e, :error)
  end
  Bot.log('Done.')
end
