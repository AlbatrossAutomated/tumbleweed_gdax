# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20180309012446) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "flipped_trades", force: :cascade do |t|
    t.string "trade_pair", default: ""
    t.decimal "quote_currency_profit", default: "0.0", null: false
    t.decimal "base_currency_purchased"
    t.decimal "base_currency_profit", default: "0.0", null: false
    t.decimal "buy_price"
    t.decimal "sell_price"
    t.decimal "buy_fee", default: "0.0", null: false
    t.decimal "sell_fee", default: "0.0", null: false
    t.decimal "revenue", default: "0.0", null: false
    t.decimal "cost", default: "0.0", null: false
    t.string "buy_order_id"
    t.string "sell_order_id"
    t.boolean "sell_pending", default: true, null: false
    t.boolean "consolidated", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.decimal "amount", null: false
    t.string "category", null: false
    t.string "description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "performance_metrics", force: :cascade do |t|
    t.decimal "base_currency_for_sale"
    t.decimal "best_bid"
    t.decimal "quote_currency_balance"
    t.decimal "base_currency_balance"
    t.decimal "quote_currency_profit"
    t.decimal "base_currency_profit"
    t.decimal "portfolio_quote_currency_value"
    t.decimal "quote_value_of_base"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "unsellable_partial_buys", force: :cascade do |t|
    t.string "trade_pair", default: ""
    t.string "string", default: ""
    t.decimal "base_currency_purchased"
    t.decimal "buy_price"
    t.decimal "buy_fee", default: "0.0", null: false
    t.string "buy_order_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

end
