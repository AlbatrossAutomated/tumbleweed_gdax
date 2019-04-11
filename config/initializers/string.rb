# frozen_string_literal: true

class String
  def valid_json?
    !!JSON.parse(self)
  rescue JSON::ParserError
    false
  end
end
