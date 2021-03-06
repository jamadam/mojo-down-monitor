/**
 * App specific script
 */
$(document).ready(function() {
	
	$(".goDetail").live('click', function(){
		$(this).find("a:first-child").trigger('click');
	});
	
	$("*[rel='external'], .external").live('click.blankEmulate', function(){
		window.open($(this).attr("href"));
		return false;
	});
	
	var mainWrapper_on_load = function() {
		$.currentTabManager('.tabStyleMenu a').fire({
			classCurrent : 'enabled'
		});
	};
	
	mainWrapper_on_load();
	
	$.pjax = function(params) {
		var beforeSend = params.beforeSend;
		params.beforeSend = function(xhr) {
			if (beforeSend) {
				beforeSend(xhr);
			}
			xhr.setRequestHeader('X-PJAX', 'true')
		};
		params.timeout = params.timeout || 10000;
		return $.ajax(params);
	}
    
    function constructNotifier(data) {
        var dom = $('<div/>', {'class':'notifier'});
        dom.append($('<div/>', {'class':'error'}).html(data));
        return dom;
    }
	
	function pjaxError(xhr, textStatus, errorThrown) {
		var notifier = constructNotifier(textStatus).css('display', 'none');
		$("#notifierContainer").prepend(notifier);
		notifier.fadeIn(function(){
			setTimeout(function(){
				notifier.fadeOut();
			}, 3000);
		});
		loading.hide();
	}
	
	var loading = $("#nowLoading");
	
	// Ajax content swap setting
	if (window.history.pushState) {
		$(window).bind('popstate', function(event) {
			loading.fadeIn('fast');
			var xhr = $.pjax({
				url: window.location,
				type: 'GET',
				success: function(data) {
					swapContent($(data));
				},
				error: pjaxError
			});
			loading.bind('click', function(){
				$(this).fadeOut();
				xhr.abort();
			});
		});
	}
	
	$("a[rel!=external]").live('click', function() {
		if (window.history.pushState) {
			loading.fadeIn('fast');
			var url = $(this).get(0).href;
			var xhr = $.pjax({
				url: url,
				type: 'GET',
				success: function(data) {
					var global = $(data);
					swapContent(global);
					var title = global.filter('title').text();
					document.title = title;
					history.pushState(null, title, url);
				},
				error: pjaxError
			});
			loading.bind('click', function(){
				$(this).fadeOut();
				xhr.abort();
			});
			return false;
		}
		return true;
	});
	
	jQuery.extend(jQuery.easing, {
		bounce: function (x, t, b, c, d) {
			return c*(t/=d)*t*t + b;
		}
	});
	
	function swapContent(global) {
		var cont_prev = $("#mainWrapper > *");
		cont = global.find("#main");
		cont.appendTo($("#mainWrapper"));
		cont_prev.css({"position":"absolute", "top":"0", "left":"0"});
		cont_prev.animate({top: "100", opacity: "0"}, 200, function(){
			$(this).remove();
		});
		cont.css({"top":"-30px", "opacity":0});
		cont.animate({top: "0",opacity: "1"}, 300, "bounce", function(){
			mainWrapper_on_load();
		});
		loading.hide();
	}
	
	$(".siteTest").live('click', function() {
		loading.fadeIn('fast');
		var params = $(this).parents('form').serialize();
		$.post('/site_test.html', params, function(data) {
			loading.hide();
			if (data.result) {
				var msg = data.result['OK'] == 1 ? 'Connection OK' : data.result['Error'] ;
				alert(msg);
			}
		});
		return false;
	});
});
