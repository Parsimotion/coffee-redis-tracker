require("coffee-script/register");
var Tracker = require("./src/metricsTracker.coffee");
var tracker = new Tracker();
module.exports = tracker;
