# frozen_string_literal: true

# -------------!! FIRST PASS - UNTESTED !!--------------
# At times GDAX will do maintenance and cancel all orders. This is a first pass
# at putting those orders back on the book when maintenance is done.
# -------------!! FIRST PASS - UNTESTED !!--------------

desc "post sell orders to exchange when they're canceled due to API maintenance"
task repost_sell_orders: :environment do
  # :nocov:
  count = 0
  reposted_count = 0

  FlippedTrade.where(sell_pending: true).find_each do |ord|
    resp = RequestUsher.execute('order', ord.sell_order_id)
    puts "RESPONSE ON GET: #{resp}"

    reposted_count += 1 if resp['id']

    puts "ALREADY REPOSTED COUNT: #{reposted_count}"
    next if resp['id']

    count += 1
    puts "Continuing with un-reposted sell orders....#{ord.id}"
    puts "REPOSTED COUNT: #{count}"

    ord_quantity = ord.base_currency_purchased
    ord_ask = ord.sell_price

    best_bid = RequestUsher.execute('quote')['bids'][0][0].to_f.round(2)
    sell_at = ord_ask <= best_bid ? (best_bid + 0.01) : ord_ask
    params = { quantity: ord_quantity, ask: sell_at.round(2) }

    sell_order = RequestUsher.execute('sell_order', params)

    if sell_order['id']
      ord.sell_order_id = sell_order['id']
      ord.sell_price = params[:ask]
      puts "PLACED SELL for #{params[:quantity]} @ price #{params[:ask]}"
      if ord.save
        puts "SUCCESS: Reposted sell & updated record for FT with id #{ord.id}"
      else
        puts "ERROR: Saving record for FT with id #{ord.id}"
      end
    else
      puts sell_order
      puts "ERROR: Reposting sell for FT with id #{ord.id}"
    end
  end
  # :nocov:
end
