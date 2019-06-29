# frozen_string_literal: true

require 'rails/application_controller'

class SettingsEstimatorController < Rails::ApplicationController
  def create
    @settings_estimator = SettingsEstimator.new(settings_estimator_params)

    if @settings_estimator.valid?
      render json: @settings_estimator.results
    else
      render json: { input_errors: @settings_estimator.errors.full_messages }
    end
  end

  private

  def settings_estimator_params
    settings = %i[
      base_currency_price
      buy_fee
      sell_fee
      quote_currency_balance
      min_trade_amount
      buy_quantity
      buy_down_interval
      profit_interval
      reserve
    ]

    params.require(:settings_estimator).permit(settings)
  end
end
