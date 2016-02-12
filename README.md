# Coffeescript Redis Tracker

```js
var Klass, Promise, Tracker, tracker;
Promise = require("bluebird");
tracker = require('coffee-redis-tracker');

function getRandomInt(min, max) {
  return Math.floor(Math.random() * (max - min)) + min;
}

Klass = (function() {
  function Klass() {}
  Klass.prototype.message = function() {
    return Promise.delay(getRandomInt(50, 500));
  };
  Klass.prototype.withCb = function(arg, second, cb) {
    return setTimeout((function(_this) {
      return function() {
        return cb(_this.state);
      };
    })(this), getRandomInt(50, 500));
  };
  return Klass;
})();

tracker.wrapCounterAndTimerOverMethod(Klass, "message", "testing");
tracker.wrapCounterAndTimerOverCallback(Klass, "withCb", "testing");

function Go(){
  new Klass().message();
  new Klass().withCb(1, 2, (function(err) { return true; }));
}

setInterval(Go, 100);

```
