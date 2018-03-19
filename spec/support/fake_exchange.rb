# frozen_string_literal: true

require 'sinatra/base'

class FakeExchange < Sinatra::Base
  get "/products/#{ENV['PRODUCT_ID']}/book" do
    return json_response 200, 'depth.json' if params[:level]
    json_response 200, 'quote.json'
  end

  get "/orders" do
    json_response 200, 'open_orders.json'
  end

  get "/accounts" do
    json_response 200, 'funds.json'
  end

  delete "/orders/:id" do
    json_response 200, 'cancel_order.json'
  end

  get "/orders/:id" do
    json_response 200, "order_#{params[:id]}.json"
  end

  post "/orders" do
    params = JSON.parse(request.body.read)
    json_response 200, "#{params['side']}_order.json"
  end

  get "/fills" do
    json_response 200, "fill_#{params[:order_id]}.json"
  end

  private

  def json_response(response_status, file_name)
    content_type :json
    status response_status
    File.read("#{::Rails.root}/spec/fixtures/files/#{file_name}")
  end
end
