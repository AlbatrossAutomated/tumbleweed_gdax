This project is for developers who are also traders. If you haven't already developed
against an exchange API where funds have been at risk, attempting to operate this
trader will likely be an unpleasant experience. Depending on your goals and
resources there are free/paid services that may suit your needs better, e.g.,
Cryptotrader, Gunbot, Enigma's Catalyst trading library, and GDAX's trading
toolkit.

You may, however, be interested in this repo even if you choose not to operate it.
The documentation thoroughly details the market making strategy it employs, and
that may be of interest to you. Or perhaps something in the codebase will be of use.

## Background
Tumbleweed is BlueCollar with one major difference. The fund protection strategy
of `COVERAGE` seen in BlueCollar is replaced here with configurable no trade zones
referred to as `CHILL_PARAMS`. This approach is new, and does not have the history
of performance and predictability of BlueCollar.

One improvement Tumbleweed has over BlueCollar is that the operator can set quantity
per trade. In BlueCollar quantity is dynamically calculated. For those with smaller
stacks, or when `COVERAGE` wasn't adequate, the calculated quantity could end up
being less than the exchange's minimum trade quantity requirement. Tumbleweed doesn't
bump up against that limitation. Tumbleweed also has the ability to pause trading,
which can have advantages over BlueCollar's aspect of always trading.

## Introduction
Tumbleweed is a market maker specialized to trade crypto-fiat pairs on the GDAX
exchange. It is available for forking and developing out further as you see fit.
It can be run out of the box, but it should be considered an Alpha level release. It
is not a turnkey or completed project. For example, if you intend to have it hosted
non-locally you will need to add your own deployment and cloud operating solutions.

## Disclaimer
Any information provided in this repository is for information purposes only.
It is not intended to be investment advice. Seek a duly licensed professional for
investment advice.

## Warning
Currently this repository is specialized to trade crypto-fiat pairs on GDAX. It
**_cannot_** be used to trade crypto-crypto pairs.  

Please read the provided documentation before running this trader. Funds given to Tumbleweed
to trade with will be at risk of loss.

Any examples in the documentation that involve the values of Tumbleweed settings
are not intended to indicate optimality.

Tumbleweed will be drawing down from the funds made available to it in order to
trade throughout market downturns. The nature of Tumbleweed’s strategy results in
periods where cash balance and overall portfolio value drop significantly. A sell
off in periods of significantly declining balances results in unrealized losses
becoming realized, and neutralizes the trader's long term strategy.

If you are simply developing out and live testing in the shorter term, it's reasonable
to prefer the liquidity of a sell off and consider any smaller losses a cost of
development.

Expect your taxes to be complicated by running Tumbleweed.

## Performance Expectations
#### When Lambo?
If you’re expecting historical HODL level returns, you’ve come to the wrong place.
This strategy isn’t designed to compete with or outdo approaches that focus on
rapidly increasing portfolio value (PV). Tumbleweed was designed as a passive income
generator; a trading system that garners regular extractable gains without having to
be reloaded with funds. It's overall performance can only be measured accurately in
the long term.

Additionally, the strategy Tumbleweed is based upon isn't envisioned as a “one
ring to rule them all” type approach, but rather as a compliment to other strategies.
In its current state it seems to perform best in periods of high price oscillation,
where the price generally isn't higher than where it was when it started trading.

#### Affordability  
The more funds Tumbleweed has access to the better it will perform nominally speaking.
The other side of that coin is that it performs better the cheaper the crypto it trades.
At the current price of GDAX's trading pairs, this is unfortunate. I'd hoped the
circle of financial accessibility would be much broader than where I think it is
today given the prices of cryptos on GDAX.

There's a lot of variables involved aside from the price of the crypto though,
so there's no hard line between who can and cannot find value in developing/operating
Tumbleweed. Nonetheless, a cheaper crypto would widen the circle, so here's hoping
GDAX lists a thriftier crypto sometime soon, or even reduces the min trade quantity
requirement on LTC.

## Strategy
> "The market goes up the market goes down. The degree to which it does so is
> variable and the timing is random."
>
> _-- Tumbleweed Motto_

#### Primary Strategy
Tumbleweed was designed as a passive income generator with a goal of resiliency
and long-term performance in the volatile cryptocurrency markets. The ability to
keep trading is prioritized over short term efforts to increase portfolio value
(cash + non-cash positions). It makes gains through the accumulation of small
amounts of profit from executed sells, which can be pocketed periodically by the
operator, given back to the trader, or some combination of the two.

By default the cumulative profits made from flipping trades are not put into the
pool of funds Tumbleweed continues to trade with. Since they aren't put back at
risk this account isn't subject to decline. It's always additive, and the funds
can be withdrawn without impacting the performance of the trader at the time of
withdrawal. Incidentally, this cumulative total is what taxes are due on.   

The main objective is protecting the initial funds from depletion so the bot is
kept alive and trading. This is done by periodically pausing trading on downturns,
and later resuming where Tumbleweed can continue to flip trades at lower prices.

The thinking was that if any trader can be kept alive and execute profitable trades
in spite of price volatility and without the operator having to give it more funds,
it will always be able to generate passive income except in two market environments:

1. A long-lived sideways market, aka a "frozen market"
2. A price collapse to 0 without a rebound

The automation of this strategy took an approach where Tumbleweed manages trading
activity based on the settings provided by an operator. So in its current state,
the trader's decisions are a factor that influences performance.

#### Characteristics
* No use of Technical Analysis (TA). It is purely reactive to events affecting the
status of its own orders.
* Buys the dip (how aggressively is configurable).
* No stop loss protection strategy. Tumbleweed never wittingly places a sell that
would result in a loss.

## Key Concepts and Terminology
**_scrum buy_**  
Attempts at making a buy where bidding, canceling, and rebidding logic is employed.
Tumbleweed only performs this kind of buy when it is started/re-started and when
all pending sell orders have executed.  

**_buy down order_**  
Any buy order placed after another buy has executed.

**_rebuy order_**  
Any buy order placed after a sell order executes, except in the case where all
sell orders have executed (then the next buy is a scrum).  

**_buy down interval_**  
A configurable setting, this is the difference in price between buy down orders.
For example, if a buy executes at $185/LTC, and the BDI is set to $0.20, the
subsequent buy will be placed at $184.80.

**_profit interval_**  
A configurable setting, this is the difference in price between an executed buy
order and its associated sell. For example, if a buy executes at $185/LTC, and the
PI is set to $0.20, The sell order will be placed at $185.20.

**_straddle_**  
The difference in price between Tumbleweed's lowest pending sell and its pending
buy. The vast majority of the time this will equal BDI + PI. If this is regularly
not the case then settings are inadequate.  

**_flipped trade_**  
Consists of a buy and it's corresponding sell after both have executed.  

**_chill params_**  
A configurable setting, this is the number of consecutive buys after which Tumbleweed
will stop trading. The amount of time to wait before resuming trading is configurable
as well. Trading resumes once the time expires, or if a sell executes while it is
waiting. In either case, trade resumption begins with a scrum buy.

**_hoarding_**  
A configurable setting, by default the cumulative quote currency profits (USD here)
made from flipping trades are not put into the pool of funds Tumbleweed continues
to trade with. They aren't put back at risk, so unlike fiat balance and the current
value of pending sells, this piece of portfolio value isn't subject to decline. The
operator can periodically decide whether to pocket these funds, give them to the
trader to leverage, or some combination of the two.

Setting this to `false` means that profits from flipped trades are instantly included
in the available funds for the trader.

**_base currency stashing_**  
A configurable setting, this could also be called 'Exchange Mining'. All or a
portion of the profits from each sell can be realized in the base currency, which
is to say some amount of the buy order quantity is not included in the sell order
quantity. It is stashed instead. This in effect is mining coins from the exchange,
or at least, high frequency dollar cost averaging.

An interesting scenario here is that if all profits are realized in the base currency
then USD costs will equal revenues. This means no tax liability for those trades.
The transactions will still need to be reported when filing but there won't be
USD gains associated with those transactions.

If I'm seeing this right there are some advantages here over mining in terms
of tax liability, as traditionally mined coins are immediately recognized as taxable
income at FMV (in addition to being taxed on gains when those mined coins are sold).
So depending on market activity, there are timeframes over which crypto can be
accumulated for net zero and therefor no tax liability.

Even without the income tax component there will still be a tax liability on stashed
coins upon exit. And it could end up that the price isn't ideal when an exit needs to
happen, but maybe a stable coin hedges this risk somehow? I also wonder what the
tax accounting would be if the 'exchange mined' coins are donated instead of sold.
Would the operator get a deduction on coins mined for net zero?

Intelligent automation that determines when to sell from the stash could also improve
Tumbleweed's numbers on the bigger upswings beyond the price where it started trading.
In my view this is where it currently underperforms.

**_profit taking_**  
Selling off of all pending orders when acceptable earnings/gains can be realized.
Described [here](../../wiki/Portfolio-Value-Matters), this process is not currently
automated but it could be.

## The Trading Cycle

![trade cycle](public/images/trade_cycle.png?raw=true)  


NOTE: Needs updating with chill params info.  
### Scrum Bidding
In order to execute a buy at the beginning of a trading cycle, the bot monitors
the market's top bid and employs logic to bid/cancel/rebid as needed so that it
keeps a limit buy at the top of the book.

### Setting Up a Straddle Position
When the scrum executes, the program places a sell order at a price that is PI
above the price of the executed scrum.

After placing the sell, the bot places a buy down order at a price that is BDI
below the price of the executed scrum. The pending buy and sell orders constitute
a straddle position, and with open orders on both sides of the book the bot is
now a 'market maker'.

The bot monitors the open orders waiting for one to fill. The execution of either
will trigger different logic.

### When the Buy Side Executes
If the buy executes, the bot places a corresponding sell, and immediately places
another buy down order. Once the buy down order is successfully placed, a new
straddle position exists, and the bot again employs the logic of monitoring it.

### When the Sell Side Executes
If a sell order executes next in this example, the bot is technically still a market
maker, since the sell placed after scrum execution is still on the book. However
the straddle between the remaining sell and buy has grown. To keep it consistent
over the course of trading, the pending buy order is canceled, and a rebuy order
is placed at a price that is PI + BDI below the price of the trader's lowest pending
sell.

### When a Straddle Clears
If all sell orders execute, then the pending buy order is cancelled, and the bot
employs its scrum bidding logic again.

### Summary
Tumbleweed is a couple of breakable loops within an infinite loop, where the inner
loops take varying amounts of time to clear, depending on market activity. The
cycles can be summed up as follows:

* A trade cycle begins with a scrum.
* When the scrum is won, the bot sets up a straddle position and monitors it.
* It continues to set up and monitor new straddle positions by placing more buy
down orders as the market goes down. It "buys the dip".
* When the market goes up and sell orders execute, the pending buy order is
cancelled, and the bot places rebuy orders to re-establish the straddle spread.
* If all sells execute, the inner loop is broken, and the bot scrums again.

## Documentation
The remainder of documentation can be found in BlueCollar's
[Wiki](https://github.com/AlbatrossAutomated/blue_collar_gdax/wiki) along with
answers to what are likely to be commonly asked questions.  

## Development
### Ruby on Rails
* Tumbleweed is an API mode Rails app.
* See .ruby-version file in application root for current ruby version.
* See Gemfile for dependencies.
* A .ruby-gemset file is located in the application root for anyone using RVM or .rbenv.

### Installation
* Clone the repository.
* Run `bundle`.
* Setup the database with `rake db:create db:migrate`.
* Set ENV vars: run `cp .env.sample .env` and fill in `'<placeholder values>'` with functional ones.

### Testing/Code Quality
#### _Run All_
The command `rake` will run the tools below in succession. If any specs fail the
subsequent checks won't be run.

- RSpec
- SimpleCov
- Brakeman
- Bundler Audit
- Rubocop

#### _Run Individually_
*_RSpec_*  
* Run the entire test suite with `rspec spec`.  
* Run only tests in some_spec.rb with `rspec spec/< path to some_spec.rb >`.  
* Run only tests beginning on line 12 in some_spec.rb `rspec spec/<path to some_spec.rb>:12`.  

*_SimpleCov_*  
* Runs automatically when specs are run. Generated test coverage report lives in `/coverage`.

*_Brakeman_*  
* Generate the report with `brakeman`.

*_BundlerAudit_*  
* Generate the report with `bundler audit`.  

*_Rubocop_*  
* Use `rubocop` to see how the code compares to the Ruby Style Guide.  
* Run `rubocop -R -a` for Rubocop to automatically fix what it knows how to fix.  

### Debugging  
* Byebug
* AwesomePrint

## GTK's Before Developing/Running Tumbleweed
#### Recently Added (not 'Battle Tested') Features
* Base Currency Stashing
* Order Backfilling default to `false`
* Reserve
* Settings Estimator

#### Trade Affordability
Tumbleweed checks the affordability of all buys. If a purchase is unaffordable the
trader loops, polling fiat balance until there is enough to afford the buy. If
it becomes affordable, the loop is broken and trading continues.
#### Exchange Min Trade Amount
At any given time if the calculated buy quantity results in less than the
exchange's minimum order size requirement Tumbleweed will place an order for the
exchange's required minimum. If the exchange's minimum order requirement can't
be afforded, the above applies.
#### Unsellable Partial Buys
Unfortunately the exchange does not hold itself to the min trade amount
requirement when filling orders. This means that when Tumbleweed cancels a buy it
may have filled in part for an amount too small to turn around and sell. These
have been pretty rare but may not be for others. Details about these trades are
stored in the `unsellable_partial_buys` table. There is no automated process
currently that aggregates and sells them when their total meets the min trade amount.
#### Breakeven Pricing
If for whatever reason a sell order placed at the set PI would result in a loss
given the cost of the associated buy, Tumbleweed will place the sell at a break
even price. However it is blind as to whether or not the sell side would ultimately
incur a taker fee. If it does, the flipped trade _could_ end up being a losing trade.
#### Reconciling Sells When Restarted
You don't need to do anything if sell orders execute while the trader was stopped.
One of the first things Tumbleweed does when it starts/re-starts is check if any
sell orders executed while it was away. If any did, it will reconcile them before
beginning the trade cycle.
#### Errors on Restart
If the trader crashes/fails in between persisting a buy order and placing a sell,
your last FlippedTrade record will likely have a `:sell_price` and `:sell_order_id`
of `nil`, which will fail during reconcile on restart. I've preferred to let the
trader choke here as a reminder the sell side wasn't handled, and I should do
something about the coins from the buy side left in my account. When this has occured,
I do what's easiest and place a sell manually for them, then delete the FlippedTrade
record, then restart.
#### Manual Trading
Recent updates should make it less problematic to manually trade the same crypto
Tumbleweed is trading. However this is not battle tested on the live exchange.

Manually trading the same crypto _may_ introduce issues around the exchange's
Self-Trade Prevention policy (STP - you can't buy your own sells and vice versa).
Tumbleweed is only tracking the orders it places which could mean a case gets
introduced where Tumbleweed places an order that matches with a manually placed
pending order. I can't think of a situation where this might occur but I'm not
yet convinced it couldn't happen.

If Tumbleweed is running, manually canceling orders it has placed will probably
have undesirable side effects.   
#### Stopping the Trader
In most cases when the trader is stopped there will be a pending buy on the
exchange. You'll probably want to cancel it which means you should log into
the exchange portal _before_ stopping the trader. That way you can quickly
move to cancel it, reducing the likelihood of it filling. If it fills you
can manually place a sell, keep the coins, whatever. A manually placed sell
order in this case won't impact Tumbleweed when it is restarted.
#### Profit Taking
The process described [here](../../wiki/Portfolio-Value-Matters) is not automated
unfortunately. I could never settle on what the trigger should be to fire it off.
Here's how it's done manually:

1. Log into the exchange.
2. Stop the trader.
3. Through the exchange, cancel all open orders.
4. Through the exchange, sell all the coins from the canceled orders (bonus points
if you don't incur a taker fee).
5. In rails console execute `FlippedTrade.pending_sells.destroy_all`.

The result of profit taking is an increase in fiat balance and the funds Tumbleweed
has access to for trading. However `flipped_trades` will have no record of where
those funds came from. A `:consolidated` bool field was once added to `flipped_trades`
in anticipation of automating profit taking. A single record with summary/average
values may suffice with `consolidated: true`. A LedgerEntry record could also be
created with `category: 'adjustment'` to account for the profit taking.

This is a also convenient moment to backup the database and store it somewhere since
there are no open positions at this point. Then you have the option to start with a
fresh database before restarting the trader.

#### De-hoarding/Reinvestment Tracking
About 4-6 times a year I want to return hoarded gains back to the trader.
Here's what I do:  
1. Log into the exchange.
2. Stop the trader.
3. Through the exchange, cancel the pending buy.  

Then in Rails console:
1. `PerformanceMetric.calculate` and note the `quote_currency_profit`
2. `le = LedgerEntry.new`  
3. `le.category = LedgerEntry::REINVESTMENT`
4. `le.amount = <the quote_currency_profit amount>`
5. `le.description = "Giving hoarded gains to the trader."`

#### Handy Commands
`PerformanceMetric.calculate` - returns a snapshot of metrics. This does not create
a db record.

`FlippedTrade.flip_count` - returns the number of flipped_trades where the sell
side has executed.

`FlippedTrade.pending_sells.count` - returns the number of flipped_trades where
the sell side is pending.

`FlippedTrade.quote_currency_profit` - returns cumulative profits from sells regardless
of whether those profits were ever de-hoarded or not.
## Running Tumbleweed
### Exchange Prerequisites
1. An account with a fiat balance. The amount needs to be enough to meet the exchange's
min trade amount requirement many times over for the crypto being traded.
2. Create an API key with _**only**_ 'View' and 'Trade' permissions (https://www.gdax.com/settings/api).

### Configure Settings
Run `cp bot_settings.sample config/initializers/bot_settings.rb`.  

You need to update the settings in `/config/initializers/bot_settings.rb` before
running Tumbleweed.

#### Appetite-to-trade Settings
The intention of these settings was to provide the operator a way to configure
Tumbleweed so that its trading activity reflects their own risk/reward comfort
level. Per trade profit, long term performance, and risk exposure are impacted
by their values. Each value's effects are described below, but their interactions
are perhaps better experienced than explained. For a more experiential understanding,
a Settings Estimator sandbox is available.

To use the Settings Estimator:  

1. Open a terminal and `cd` into the `tumbleweed_gdax` directory.
2. Enter `rails s` to start the local server.
3. Visit localhost:3000 in a browser.
4. Use the form to change various settings and see the results.

<u>_Main Appetite Settings_</u>  

**`CHILL_PARAMS`**  
Hash: `{ consecutive_buys: x, wait_time: y }`

If x number of consecutive buys execute (the price is falling), pause trading for y
amount of time. Trading resumes if time expires or if a sell executes (the price is rising)
while trading is paused. The advantage of pausing while the price falls is simply
about survivability and stretching the funds.

* As this fund stretching mechanism is new, I won't hazard a guess just yet about the
impact of this setting.  

**`BUY_DOWN_INTERVAL`**  
Float: The difference in price between subsequent buys.
* All other factors being equal, the bigger the BDI the more profit
will be made per sell.

* During periods of smaller market price oscillations relative to the BDI, a larger
BDI results in fewer buy order executions, as the price is moving down less frequently
enough to fill them. This leads to fewer sells getting placed and therefore fewer
sells executing.

* A very low BDI may result in per trade profits that are undesirably small.

* The lower the BDI the more likely it becomes that buy orders will incur a taker fee.  

**`PROFIT_INTERVAL`**  
Float: The difference in price between a buy order and the subsequent sell.
* All other factors being equal, the bigger the PI the more profit will be made per sell.

* During periods of smaller market price oscillations relative to the PI, a larger
value results in fewer sell orders executing, as the price is moving up less frequently
enough to fill them.

* The larger the PI the more likely it is that the protection calculation will execute
less frequently.

* A very small PI may result in per trade profits that are undesirably small relative
to the cost of the buy.

* The smaller the PI the more likely it becomes that sell orders will incur a taker fee.

<u>_Other Appetite Settings_</u>  

**`HOARD_QUOTE_PROFITS`**  
Boolean (default is `true`): separate cumulative quote currency profits from the
available funds to trade with, or include them.  

* All other settings being equal, setting this to `false` will improve performance.

* If set to `false` and a decision is later made to withdraw gains from flipping trades,
then per trade performance will be lower post-withdrawal, short of other settings being
changed.

* If set to `true` and coverage proves inadequate to the point where all tradable funds
end up in pending sell orders, the option to give the hoarded gains to Tumbleweed
for leveraging would be on the table.

**`BASE_CURRENCY_STASH`**  
Float (default is 0.0): A percent of per sell profit as decimal, 0.0 to 1.0.

* For example, if this was set at 20% and quote profit (USD) was $0.05, then $0.01
worth of the base currency will not be included in the sell order quantity, and
quote profit would be $0.04. If 100% of profit is realized in the base currency
then costs of the buys should equal revenue of the sells.

**`ORDER_BACKFILLING`**  
Boolean (default is `false`): If the trader is stopped or crashed, and the price has
dropped during the downtime by an amount greater than the straddle, do or don't
backfill orders over that price range when the trader is restarted.

This is set to `false` because the behavior is **NOT** always ideal, particularly
with a small stack and when the price has dropped significantly from where it was
when the trader was stopped. It's also perfectly reasonable for the operator to
strategically stop the trader especially if they think there will be a significant
decline in price. Why not come back in at a lower price point where tradable funds
will go further and improve performance?

* If set to `true` when Tumbleweed is restarted it will scrum. If the scrum fills
it will place a sell and a buy down as usual. If/when the sell associated with
the scrum executes, Tumbleweed will look to the lowest pending sell and backfill
orders all the way to current market price as if it never stopped trading. One
possible advantage of this is described [here](../../wiki/Hidden-Gains).

#### Other Settings  
**`RESERVE`**  
Float (default is 0.0): The amount of fiat in your GDAX account to exclude Tumbleweed
from trading. Handy if you have funds in your account that you want to use for other
exchange activity, or if you just want to test drive or develop out Tumbleweed.

**`CANCEL_RETRIES`**  
Integer (default is 15): the number of times BluCollar should retry canceling an
order before assuming it failed to get on the book.

When placing/canceling an order, a 200 response from GDAX does not mean
the order is on the book or canceled. Some processing occurs post-response
before an order is added to or removed from the book. In the case of a cancel,
this gets interesting, as a 'NotFound' is the response you can get in the following
cases:  

**A:** A buy_order is placed, an attempt is made to cancel it, but the buy_order
has not yet hit the order book.

**B:** A buy_order is placed, an attempt is made to cancel it, but ultimately the
buy_order failed to post on the order book.  

I don't think I've seen a failure to ultimately post on GDAX in a while so this
setting may just be about handling the lag case.

_*NOTE:*_ There is a Case **C**. GDAX permanently removes orders that are canceled
in their entirety, after which the response is 'NotFound' on subsequent `GET`s. In
this case 'Not Found' is confirmation that an order truly canceled.
(see Trader.cancel_buy for how this is handled).  

**`PRINT_MANTRA`**  
Boolean: Turn off/on the message that's logged every time the outermost loop cycles.  

### Performance Metrics
The background scheduler gem [clockwork](https://github.com/Rykian/clockwork) is
used to record various metrics every 4 hours. If you'd like to do this more or
less frequently, edit `clock.rb`.  

To have performance metrics recorded during trading activity, run:

`clockwork clock.rb`

### Deployment/Hosting
Roll your own. My preference has been to run it locally on a spare machine. I find
it much easier to develop and intervene while also viewing the exchange's web portal.
It has been run on Heroku. For various other hosting services, you'd likely need
to implement your favorite solution for starting/stopping 'forever running' processes.

### Start the Trader Locally  
```
rails c  

Trader.begin_trade_cycle
```  

## License
Tumbleweed is open source under the MIT license. See [LICENSE](LICENSE) for more details.

## Donations
**BTC**: 17yTLEEgs4yMiFCcboYKsXT9wsQ9XVpvAC  
**ETH**: 0x6C40eA9fD6d00539f22B0Cf5Db2C54152326288c  
**LTC**: LU6LRhAXLWGWB3BzPsyGygK6JyqVEBbayg
