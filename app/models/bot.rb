# frozen_string_literal: true

class Bot
  class << self
    def log(phrase, data = nil, log_level = :info)
      # :nocov:
      unless Rails.env.test?
        Rails.logger.ap phrase, log_level
        Rails.logger.ap data if data
      end
      # :nocov:
    end

    def sleep(secs)
      Kernel.sleep(secs)
    end

    # :nocov:
    def mantra
      mantra_spacer
      mantra_1
      mantra_spacer
      mantra_2
      mantra_spacer
      mantra_3
      mantra_spacer
      mantra_4
      mantra_spacer
    end

    def mantra_spacer
      puts "\n"
    end

    def mantra_1
      puts "'|.   '|'          ||    .   '||                                ".cyan
      puts " |'|   |    ....  ...  .||.   || ..     ....  ... ..      ....  ".cyan
      puts " | '|. |  .|...||  ||   ||    ||' ||  .|...||  ||' ''    '' .|| ".cyan
      puts " |   |||  ||       ||   ||    ||  ||  ||       ||        .|' || ".cyan
      puts ".|.   '|   '|...' .||.  '|.' .||. ||.  '|...' .||.       '|..'|'".cyan
    end

    def mantra_2
      puts "'||                                                                 ".cyan
      puts " || ...    ...   ... ..  ... ..    ...   ... ... ...   ....  ... .. ".cyan
      puts " ||'  || .|  '|.  ||' ''  ||' '' .|  '|.  ||  ||  |  .|...||  ||' ''".cyan
      puts " ||    | ||   ||  ||      ||     ||   ||   ||| |||   ||       ||    ".cyan
      puts " '|...'   '|..|' .||.    .||.     '|..|'    |   |     '|...' .||.   ".cyan
    end

    def mantra_3
      puts ".. ...     ...   ... ..      ....  ".cyan
      puts " ||  ||  .|  '|.  ||' ''    '' .|| ".cyan
      puts " ||  ||  ||   ||  ||        .|' || ".cyan
      puts ".||. ||.  '|..|' .||.       '|..'|'".cyan
    end

    def mantra_4
      puts "'||                        '||                     '||             ".cyan
      puts " ||    ....  .. ...      .. ||    ....  ... ..      || ...    .... ".cyan
      puts " ||  .|...||  ||  ||   .'  '||  .|...||  ||' ''     ||'  || .|...||".cyan
      puts " ||  ||       ||  ||   |.   ||  ||       ||         ||    | ||     ".cyan
      puts ".||.  '|...' .||. ||.  '|..'||.  '|...' .||.        '|...'   '|...'".cyan
    end
    # :nocov:
  end
end
