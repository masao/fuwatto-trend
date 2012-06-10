// Load the Visualization API and the piechart package.
google.load('visualization', '1.0', {'packages':['corechart']});

// Set a callback to run when the Google Visualization API is loaded.
google.setOnLoadCallback( get_trend_data );

var fuwatto_trend_data = {};

function get_trend_data() {
  var targets = $('#form input[name=target]:checkbox:checked');
  var q = $('#form input[name=q]').val();
  if ( q.length > 0 ) {
    $('#chart_div').html( '<span style="text-align:center"><img src="./ajax-loader.gif" alt=""/> loading...</span>' );
    for (var i = 0; targets.length > i; i += 1) {
      $.ajax({
        url: "search.rb?q="+encodeURIComponent(q)+"&target="+targets[i].value,
        dataType:"json",
	error: function( header, status, error ) {
	  $('#chart_div').append( '<div class="error">unknown error. ['+
	  			  status +':'+ error +']</div>' );
	},
        success: function( data, status ){
  	  var target = data[ "target" ];
  	  var label = data[ "label" ];
  	  var q = data[ "q" ];
  	  if ( target ) {
  	    if ( label ) {
  	      fuwatto_trend_data[ target ] = { "label" : label };
  	    }
  	    if ( !fuwatto_trend_data[ q ] ) {
  	      fuwatto_trend_data[ q ] = {};
  	    }
  	    if ( !fuwatto_trend_data[ q ][ target ] ) {
  	      fuwatto_trend_data[ q ][ target ] = data[ "pubyear" ];
  	    }
  	    drawChart( q );
  	  }
        }
      });
    }
  }
}

function drawChart( q ) {
  var data = new google.visualization.DataTable();
  data.addColumn( { type:'number', label:'Publication Year', pattern:"###0" });
  var pubyears = [];
  if ( fuwatto_trend_data[ q ] ) {
    var targets = $.map( fuwatto_trend_data[ q ], function(v,k){ return k; } );
    for (var i in targets) {
      var target = targets[ i ];
      data.addColumn( 'number', fuwatto_trend_data[target]["label"], target );
      var trend_data = fuwatto_trend_data[ q ][ target ];
      var pubyear = $.map( trend_data, function(v,k){ return k; } );
      pubyears = pubyears.concat( pubyear );
    }
    $.unique( pubyears );
    pubyears.sort();
    for ( var y in pubyears ) {
      var row = [ Number(pubyears[y]) ];
      for (var i in targets) {
	var target = targets[ i ];
	var val = fuwatto_trend_data[ q ][ target ][ pubyears[y] ] || 0;
	row = row.concat( val );
	//alert( row );
      }
      data.addRow( row );
    }

    // Set chart options
    var options = {
      title: 'Article/Book Trends',
      hAxis: {
	format: '###0'
      },
      height: 200
    };
    var chart = new google.visualization.LineChart(document.getElementById('chart_div'));
    chart.draw(data, options);
  }
}
