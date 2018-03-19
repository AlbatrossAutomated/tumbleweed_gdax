# frozen_string_literal: true
class String
  def is_json?
    !!JSON.parse(self)
  rescue
    false
  end
end
