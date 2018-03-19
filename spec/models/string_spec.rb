# frozen_string_literal: true

require 'rails_helper'

RSpec.describe String, type: :model do
  describe '#is_json?' do
    let(:valid_json) { { foo: 'bar' }.to_json }
    let(:invalid_json) { ' ' }

    it 'returns true for valid json' do
      expect(valid_json.is_json?).to be true
    end

    it 'returns false for invalid json' do
      expect(invalid_json.is_json?).to be false
    end
  end
end
