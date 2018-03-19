# frozen_string_literal: true

# :nocov:
require 'rubocop/rake_task'

desc 'Rubopcop code quality check'
RuboCop::RakeTask.new(:rubocop) do |t|
  t.options = ['--display-cop-names']
end

task default: [:rubocop]
# :nocov:
