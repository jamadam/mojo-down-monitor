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
	
	// Ajax content swap setting
	if (window.history.pushState) {
		$(window).bind('popstate', function() {
			loading.fadeIn('fast');
			var xhr = $.ajax({
				url: Document.URL,
				type: 'GET',
				complete: function(xhr) {
					var global = $(xhr.responseText);
					swapContent(global);
				},
				beforeSend: function(xhr){
					xhr.setRequestHeader('X-PJAX', 'true')
				}
			});
			loading.bind('click', function(){
				$(this).fadeOut();
				xhr.abort();
			});
		});
	}
	
	$("a").live('click', function() {
		if (window.history.pushState) {
			loading.fadeIn('fast');
			var url = $(this).get(0).href;
			var xhr = $.ajax({
				url: url,
				type: 'GET',
				complete: function(xhr) {
					var global = $(xhr.responseText);
					var title = global.filter('title').text();
					swapContent(global);
					history.pushState(null, title, url);
				},
				beforeSend: function(xhr){
					xhr.setRequestHeader('X-PJAX', 'true')
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
