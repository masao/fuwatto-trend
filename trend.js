$(document).ready(function(){
  var q = get_trend_data();
  bind_chart_event( q );
});

var fuwatto_trend_data = {};
var fuwatto_event_point = {
  click: null,
  hover: null
};

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
  	    drawChart_flot( q );
  	  }
        }
      });
    }
  }
  return q;
}

function drawChart_flot( q ) {
  var data = [];
  var pubyears = [];
  if ( fuwatto_trend_data[ q ] ) {
    var targets = $.map( fuwatto_trend_data[ q ], function(v,k){ return k; } );
    for (var i in targets) {
      var target = targets[ i ];
      var trend_data = fuwatto_trend_data[ q ][ target ];
      var pubyear = $.map( trend_data, function(v,k){ return k; } );
      pubyears = pubyears.concat( pubyear );
      data[ i ] = {
        label: fuwatto_trend_data[target]["label"],
	data: []
      };
    }
    $.unique( pubyears );
    pubyears.sort();
    for ( var y in pubyears ) {
      for (var i in targets) {
	var target = targets[ i ];
	var val = 0;
	var this_year_data = fuwatto_trend_data[ q ][ target ][ pubyears[y] ];
	if ( this_year_data && this_year_data[ "number" ] ) {
	  val = this_year_data[ "number" ];
	}
	data[ i ][ "data" ].push( [ Number(pubyears[y]), val ] );
	//alert( row );
      }
    }

    // Set chart options
    var options = {
      title: 'Article/Book Trends',
      hAxis: {
	format: '###0'
      },
      height: 200,
      allowHtml: true
    };
    $.plot($("#chart_div"), data, {
      xaxis: { tickDecimals: 0 },
      yaxis: { tickDecimals: 0 },
      grid: {
	hoverable: true,
	clickable: true
      }
    });
    $("#chart_title").text( 'Article/Book Trends' );
  }
}

function showTooltip( identifier, x, y, contents) {
  $('<div id="' + identifier + '">' + contents + '</div>').css( {
    position: 'absolute',
    display: 'none',
    top: y + 5,
    left: x + 5,
    border: '1px solid #fdd',
    padding: '2px',
    'background-color': '#fee',
    opacity: 0.80,
    'font-size': 'smaller'
  }).appendTo("body").fadeIn(200);
}

function handleTooltip( type, item, q ) {
  //alert( Object.keys( item.series ) );
  //alert( Object.keys( item ) );
  //alert( Object.keys( pos ) );
  var identifier = 'tooltip_' + type;
  if (item && fuwatto_event_point[ type ] != item.dataIndex) {
    fuwatto_event_point[ type ] = item.dataIndex;
    $( '#' + identifier ).remove();
    var x = item.datapoint[0];
    var y = item.datapoint[1];
    var targets = $.map( fuwatto_trend_data[ q ], function(v,k){ return k; } );
    var target = targets[ item.seriesIndex ];
    var this_year_data = fuwatto_trend_data[ q ][ target ][ x ];
    if ( this_year_data ) {
      var url = this_year_data[ "url" ];
      //alert( [ x, url ] );
      if ( url ) {
        showTooltip( identifier, item.pageX, item.pageY,
	             '<b>' + x + '</b>: <a target="_blank" href="'+ url +'">' + y + '</a>' );
      } else {
        showTooltip( identifier, item.pageX, item.pageY,
	             '<b>' + x + '</b>: ' + y + '</a>' );
      }
    }
  } else {
    $( '#' + identifier ).remove();
    fuwatto_event_point[ type ] = null;
  }
}

function bind_chart_event( q ) {
  $("#chart_div").bind("plothover", function (event, pos, item) {
    handleTooltip( "hover", item, q );
  });
  $("#chart_div").bind("plotclick", function (event, pos, item) {
    handleTooltip( "click", item, q );
  });
}


function drawChart_google_chart( q ) {
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
      height: 200,
      allowHtml: true
    };
    var chart = new google.visualization.LineChart(document.getElementById('chart_div'));
    chart.draw(data, options);
  }
}
