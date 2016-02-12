should = require 'should'
simple = require 'simple-mock'
Promise = require("bluebird")
Tracker = require '../src/metricsTracker'

STATE = null
fn = null
fnIncr = null
fnIncrBy = null
client = null
mt = null

class TestClass
  constructor: (@state) ->
  method: =>
    fn @state
  withCb: (arg, cb) ->
    setTimeout () => cb(@state),
    400

class FakeClient
  timeAsync: =>
    Promise.resolve ["1455139681", "799370"] #redis time response: Wed Feb 10 2016 18:28:01 GMT-0300 (Argentina Standard Time)
  incrAsync: (args...) =>
  incrbyAsync: (args...) =>

describe "MetricsTracker", ->
  beforeEach ->
    fn = simple.stub().returnWith Promise.delay(400)
    client = new FakeClient()
    simple.mock(client, 'incrAsync').returnWith Promise.delay(100)
    simple.mock(client, 'incrbyAsync').returnWith Promise.delay(100)
    mt = new Tracker(client)

  describe "#wrapCounterAndTimerOverCallback", ->
    it "when the orginal method is called this variable should not change", (done) ->
      mt.wrapCounterAndTimerOverCallback TestClass, "withCb"
      STATE = "someState"
      cb = simple.stub()
      new TestClass(STATE).withCb("arg", cb)
      Promise.delay(1000).then -> #hack the right way is put it in callback
        should(cb.callCount).be.exactly 1
        should(cb.lastCall.arg).be.exactly STATE
        done()

    it "incrAsync should be called with correct arguments", (done) ->
      mt.wrapCounterAndTimerOverCallback TestClass, "withCb", "sufix"
      cb = simple.stub()
      new TestClass(STATE).withCb("arg", cb)
      Promise.delay(1000).then -> #Delay because redis promise is lost because his result doesnt matter
          should(client.incrAsync.lastCall.arg).be.exactly "TestClass-withCb-sufix-2016-2-10-21-30"
          should(client.incrAsync.callCount).be.exactly 1
          done()

    it "incrbyAsync should be called with correct arguments", (done) ->
      mt.wrapCounterAndTimerOverCallback TestClass, "withCb", "sufix"
      cb = simple.stub()
      new TestClass(STATE).withCb("arg", cb)
      Promise.delay(1000).then -> #Delay because redis promise is lost because his result doesnt matter
          should(client.incrbyAsync.lastCall.arg).be.exactly "time-TestClass-withCb-sufix-2016-2-10-21-30"
          should(client.incrbyAsync.callCount).be.exactly 1
          should(client.incrbyAsync.lastCall.args[1] > 390).be.true()
          done()

  describe "#wrapCounterOverCallback", ->
    it "when the orginal method is called this variable should not change", (done) ->
      mt.wrapCounterOverCallback TestClass, "withCb"
      STATE = "someState"
      cb = simple.stub()
      new TestClass(STATE).withCb("arg", cb)
      Promise.delay(1000).then -> #hack the right way is put it in callback
        should(cb.callCount).be.exactly 1
        should(cb.lastCall.arg).be.exactly STATE
        done()

    it "incrAsync should be called with correct arguments", (done) ->
      mt.wrapCounterOverCallback TestClass, "withCb", "sufix"
      cb = simple.stub()
      new TestClass(STATE).withCb("arg", cb)
      Promise.delay(1000).then -> #Delay because redis promise is lost because his result doesnt matter
          should(client.incrAsync.lastCall.arg).be.exactly "TestClass-withCb-sufix-2016-2-10-21-30"
          should(client.incrAsync.callCount).be.exactly 1
          done()

    it "incrAsync isn't called", (done) ->
      mt.wrapCounterOverCallback TestClass, "withCb", "sufix"
      cb = simple.stub()
      new TestClass(STATE).withCb("arg", cb)
      Promise.delay(1000).then -> #Delay because redis promise is lost because his result doesnt matter
          should(client.incrbyAsync.callCount).be.exactly 0
          done()

  describe "#wrapCounterAndTimerOverMethod", ->
    it "when the orginal method is called this variable should not change", (done) ->
      mt.wrapCounterAndTimerOverMethod TestClass, "method"
      STATE = "aState"
      new TestClass(STATE).method().then ->
        should(fn.callCount).be.exactly 1
        should(fn.lastCall.arg).be.exactly STATE
        done()

    it "incrAsync should be called with correct arguments", (done) ->
      mt.wrapCounterAndTimerOverMethod TestClass, "method", "sufix"
      new TestClass().method().then ->
        Promise.delay(800).then -> #Delay because redis promise is lost because his result doesnt matter
          should(client.incrAsync.lastCall.arg).be.exactly "TestClass-method-sufix-2016-2-10-21-30"
          should(client.incrAsync.callCount).be.exactly 1
          done()

    it "incrbyAsync should be called with correct arguments", (done) ->
      mt.wrapCounterAndTimerOverMethod TestClass, "method", "sufix"
      new TestClass().method().then ->
        Promise.delay(800).then -> #Delay because redis promise is lost because his result doesnt matter
          should(client.incrbyAsync.lastCall.arg).be.exactly "time-TestClass-method-sufix-2016-2-10-21-30"
          should(client.incrbyAsync.lastCall.args[1] > 390).be.true() #sometime nodejs resoves Promise.delay(400) a copuple of microseconds before
          should(client.incrbyAsync.callCount).be.exactly 1
          done()

  describe "#wrapCounterOverMethod", ->
    it "when the orginal method is called this variable should not change", (done) ->
      mt.wrapCounterOverMethod TestClass, "method"
      STATE = "otherState"
      new TestClass(STATE).method().then ->
        should(fn.callCount).be.exactly 1
        should(fn.lastCall.arg).be.exactly STATE
        done()

    it "incrAsync should be called with correct arguments", (done) ->
      mt.wrapCounterOverMethod TestClass, "method", "sufix"
      new TestClass().method().then ->
        Promise.delay(800).then -> #Delay because redis promise is lost because his result doesnt matter
          should(client.incrAsync.callCount).be.exactly 1
          should(client.incrAsync.lastCall.arg).be.exactly "TestClass-method-sufix-2016-2-10-21-30"
          done()

    it "incrAsync isn't called", (done) ->
      mt.wrapCounterOverMethod TestClass, "method", "sufix"
      new TestClass().method().then ->
        Promise.delay(800).then -> #Delay because redis promise is lost because his result doesnt matter
          should(client.incrbyAsync.callCount).be.exactly 0
          done()

  it "when It is border hour should set next hour", ->
    class TimeFakeClient
      timeAsync: =>
        date = new Date('Thu Feb 11 2016 17:59:20 GMT-0300').getTime()
        first = "#{Math.trunc(date / 1000)}"
        second = "000000"
        Promise.resolve [first, second] #redis time response
    mt = new Tracker(new TimeFakeClient())
    mt._getDateKey().then (dateKey) ->
      should(dateKey).be.exactly "2016-2-11-21-0"

  it "when It is border day should set next hour", ->
    class TimeFakeClient
      timeAsync: =>
        date = new Date('Thu Feb 11 2016 20:59:20 GMT-0300').getTime()
        first = "#{Math.trunc(date / 1000)}"
        second = "000000"
        Promise.resolve [first, second] #redis time response
    mt = new Tracker(new TimeFakeClient())
    mt._getDateKey().then (dateKey) ->
      should(dateKey).be.exactly "2016-2-12-0-0"
