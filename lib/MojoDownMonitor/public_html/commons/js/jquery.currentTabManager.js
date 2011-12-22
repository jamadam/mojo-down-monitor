/*!
 * currentTabManager 0.02 - add class for current tab
 * 
 * SYNOPSIS
 * 
 * $.currentTabManager("#target a").fire();
 * $.currentTabManager("#target a").fire({});
 * $.currentTabManager("#target a").fire({
 *		event : 'dblclick',
 *		classCurrent : 'someClassName'
 * }, url);
 *
 * Copyright (c) 2010 Cutout Inc.
 * 
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 */
;(function($) {

    /**
     * plugin name
     */
    var plugname = 'currentTabManager';
    
    $[plugname] = $.sub();
    
    /**
     * enable
     */
    $[plugname].fn.fire = function(opt, url){
        
        opt = $.extend({
            event : 'click.' + plugname,
            classCurrent : 'enabled'
        }, opt || {});
        
        currentUrl = urlNormalize(url || document.URL);
        
        var parent = this;
        var target;
        var length = 0;
        
        $(this).each(function() {
            
            $(this).removeClass(opt.classCurrent);
            
            var candidate = urlNormalize(this.href);
            
            while (candidate.match(/\//)) {
                if (currentUrl.indexOf(candidate) != -1 && candidate.length > length) {
                    target = $(this);
                    length = candidate.length;
                    break;
                }
                candidate = dirTraverse(candidate);
            }
            
            $(this).unbind(opt.event);
            $(this).bind(opt.event, function () {
                $[plugname](parent).fire(opt, this.href);
            });
        });
        
        if (target) {
            target.addClass(opt.classCurrent);
        }
        
        return $(this);
    };
    
    function urlNormalize(url) {
        url = url.replace(/^.+?\/\/+/, '');
        url = url.replace(/\\/g, '/');
        return url;
    }
    
    function dirTraverse(url) {
        if (url.match(/(#|\?).+/)) {
            return url.replace(/(#|\?).+/, '');
        }
        if (url.match(/\.html?$/)) {
            return url.replace(/\.html?$/, '');
        }
        if (url.match(/[A-Za-z0-9]+$/)) {
            return url.replace(/[A-Za-z0-9]+$/, '');
        }
        if (url.match(/[^A-Za-z0-9]$/)) {
            return url.replace(/[^A-Za-z0-9]$/, '');
        }
        return '';
    }
})(jQuery);
