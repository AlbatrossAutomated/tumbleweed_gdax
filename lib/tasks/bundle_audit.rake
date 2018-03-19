# frozen_string_literal: true

# :nocov:
# sourced from http://caseywest.com/run-bundle-audit-from-rake/
require 'bundler/audit/cli'

namespace :bundle_audit do
  desc 'Update bundle-audit database'
  task :update do
    Bundler::Audit::CLI.new.update
  end

  desc 'Check gems for vulns using bundle-audit'
  task :check do
    puts "Running bundle-audit check..."
    Bundler::Audit::CLI.new.check
    puts "Done with bundle audit check.\n\n"
  end

  desc 'Update vulns database and check gems using bundle-audit'
  task :run do
    Rake::Task['bundle_audit:update'].invoke
    Rake::Task['bundle_audit:check'].invoke
  end
end

task :bundle_audit do
  Rake::Task['bundle_audit:run'].invoke
end

task default: ["bundle_audit:check"]
# :nocov:
