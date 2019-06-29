$(document).ready(function() {
  $('form').submit(function(event) {
    event.preventDefault();

    // reset elements visibility/content states
    $('.input-errors, .results-errors').hide();
    $('#results-summary').hide();
    $('#trade-detailed, .input-errors-list, .results-errors-list').empty();

    var data = $(this).serialize()

    $.post('http://localhost:3000/settings_estimator', data).done(function(resp) {
      if(resp.input_errors) {
        showInputErrors(resp.input_errors);
      } else {
        showResultsErrors(resp.results_errors);
        addKeyEstimates(resp);
        addTradeDetailed(resp.trade_detailed)
        displayResults();
      };
    });
  });

  // listeners
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
  $('#quantity-buy').html(resp.buy_quantity);
  $('#quantity-sell').html(resp.sell_quantity);
  $('#quote-profit-per-sell').html(resp.quote_profit_per_sell);
}

function addTradeDetailed(trade) {
  var rowData = '<td>' + trade.balance + '</td>' +
                '<td>' + trade.buy_price + '</td>' +
                '<td>' + trade.buy_quantity + '</td>' +
                '<td>' + trade.buy_fee + '</td>' +
                '<td>' + trade.total_cost + '</td>' +
                '<td>' + trade.sell_price + '</td>' +
                '<td>' + trade.sell_quantity + '</td>' +
                '<td>' + trade.sell_fee + '</td>' +
                '<td>' + trade.total_revenue + '</td>' +
                '<td>' + trade.quote_profit + '</td>'

  $('#trade-detailed').append('<tr>' + rowData + '</tr>');
}

function displayResults() {
  $('#results-summary').show();
}
