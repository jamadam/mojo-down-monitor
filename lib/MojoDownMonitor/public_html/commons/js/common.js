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
	
	var loading = $("#nowLoading");
	
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
				error: function(xhr, textStatus, errorThrown) {
					console.log(textStatus);
				}
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
				error: function(xhr, textStatus, errorThrown) {
					console.log(textStatus);
				}
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
});
