# Coffeescript Redis Tracker

```coffeescript
Promise = require("bluebird")
Tracker = require './metricsTracker'
tracker = new Tracker()

class Klass
  message: ->
    Promise.delay(400)
  withCb: (arg, second, cb) ->
    setTimeout () => cb(@state),
    400


tracker.wrapCounterAndTimerOverMethod Klass, "message", "testing"
tracker.wrapCounterAndTimerOverMethod Klass, "withCb", "testing"

new Klass().message()
new Klass().withCb(1, 2,
(err) => true)
```
