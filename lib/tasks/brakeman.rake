# frozen_string_literal: true

# :nocov:
desc 'Security check via brakeman'
task :brakeman do
  if system('brakeman -q')
    puts 'Security check succeed'
  else
    puts 'Security check failed'
    exit 1
  end
end
task default: [:brakeman]
# :nocov:
