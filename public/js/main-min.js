(function(){var o;o=angular.module("peer2package",["ui.router"]),o.config(function(o,t){return o.state("main",{templateUrl:"home.html",controller:"mainController"}).state("about",{templateUrl:"about.html",controller:"aboutController"})}),o.controller("mainController",function(o){}),o.controller("menuController",function(o){return o.authStatus=!1,console.log(regForm)}),o.controller("mapController",function(o){}),o.controller("aboutController",function(o){})}).call(this);