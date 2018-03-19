$(document).ready(function() {
  $('form').submit(function(event) {
    event.preventDefault();

    // reset elements visibility/content states
    $('.input-errors, .results-errors').hide();
    $('#results-summary').hide();
    $('#free-fall-trades, .input-errors-list, .results-errors-list').empty();
    $('#free-fall-trades-toggle > input').prop('checked', false)
    $('#trades, #toggle-hint-checked').addClass('hide');
    $('#first-trade, #toggle-hint-default').removeClass('hide');

    var data = $(this).serialize()

    $.post('http://localhost:3000/settings_estimator', data).done(function(resp) {
      if(resp.input_errors) {
        showInputErrors(resp.input_errors);
      } else {
        showResultsErrors(resp.results_errors);
        addKeyEstimates(resp);
        addFreeFallTrades(resp.free_fall_trades);
        displayResults();
      };
    });
  });

  // listeners
  $('#free-fall-trades-toggle > .slider.round').on('click', function() {
    $('#free-fall-trades > tr:not(:first-of-type)').toggle();
    $('#trades, #first-trade, #toggle-hint-default, #toggle-hint-checked').toggleClass('hide');
  })

  $('.close').on('click', function() {
    $(this).parent().hide();
  });
});

function showInputErrors(inputErrors) {
  showErrors(inputErrors, 'input')
}

function showResultsErrors(resultsErrors) {
  if(resultsErrors.length > 0) {
    showErrors(resultsErrors, 'results')
  };
}

function showErrors(errors, category) {
  $.each(errors, function(index, val) {
    $('.' + category + '-errors-list').append('<li>' + val + '</li>');
  });

  $('.' + category + '-errors').show();
}

function addKeyEstimates(resp) {
  var lastTradeIndex = resp.free_fall_trades.length - 1
  var coveredToPrice = resp.free_fall_trades[lastTradeIndex].buy_price
  // var percentProfit = ((resp.quote_profit_per_sell / resp.free_fall_trades[0].cost) * 100).toFixed(4);

  $('#quantity-buy').html(resp.buy_quantity);
  $('#quantity-sell').html(resp.sell_quantity);
  $('#quote-profit-per-sell').html(resp.quote_profit_per_sell);
  $('#base-profit-per-sell').html(resp.base_profit_per_sell);
  $('#covered-to').html(coveredToPrice);
}

function addFreeFallTrades(trades) {
  $.each(trades, function(index, val) {
    var rowData = '<td>' + val.balance + '</td>' +
                  '<td>' + val.buy_price + '</td>' +
                  '<td>' + val.buy_quantity + '</td>' +
                  '<td>' + val.buy_fee + '</td>' +
                  '<td>' + val.total_cost + '</td>' +
                  '<td>' + val.sell_price + '</td>' +
                  '<td>' + val.sell_quantity + '</td>' +
                  '<td>' + val.sell_fee + '</td>' +
                  '<td>' + val.total_revenue + '</td>' +
                  '<td>' + val.quote_profit + '</td>' +
                  '<td>' + val.base_profit + '</td>'

    $('#free-fall-trades').append('<tr>' + rowData + '</tr>');
  });
}

function displayResults() {
  $('#free-fall-trades > tr:not(:first-of-type)').hide();
  $('#results-summary').show();
}
