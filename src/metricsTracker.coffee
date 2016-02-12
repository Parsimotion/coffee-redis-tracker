Promise = require("bluebird")
redis = require "redis"
Promise.promisifyAll(redis.RedisClient.prototype);
Promise.promisifyAll(redis.Multi.prototype);

TIME_INTERVAL = process.env.TIME_INTERVAL || 5

REDIS_HOST = process.env.REDIS_HOST || "localhost"
REDIS_PORT = process.env.REDIS_PORT || 6379
REDIS_AUTH = process.env.REDIS_AUTH

class MetricsTracker
  constructor: (cli) ->
    authPass = if REDIS_AUTH then {db: 3, auth_pass: REDIS_AUTH, tls: {servername: REDIS_HOST}} else null
    @client = cli || redis.createClient(REDIS_PORT, REDIS_HOST, authPass)

    @time = @client.timeAsync().then (time) ->
      millisec = Number.parseInt(time[0] + time[1].slice(0,3))
      remoteTime:millisec
      hostTime: new Date().getTime()

  _getDateKey: ->
    @time.then (time) =>
      cordinatedTime = time.remoteTime + @_getTimeFromStarting(time)
      cordinatedDate = new Date(cordinatedTime)
      year = cordinatedDate.getUTCFullYear()
      month = cordinatedDate.getUTCMonth() + 1
      day = cordinatedDate.getUTCDate()
      hour = cordinatedDate.getUTCHours()
      minute = cordinatedDate.getUTCMinutes()
      "#{year}-#{month}-#{@_day(day, hour, minute)}-#{@_hour(hour, minute)}-#{@_minute(minute)}"

  _increaseKeyAndAddTime: (key, startTime) =>
    elapsedTime = @_elapsedTimeInMicroseconds startTime
    @_increaseKey(key).then (dateKey) =>
      @client.incrbyAsync("time-#{key}-#{dateKey}", elapsedTime)

  _increaseKey: (key) =>
    @_getDateKey().then (dateKey) =>
      @client.incrAsync("#{key}-#{dateKey}").then -> dateKey

  _getTimeFromStarting: (time) ->
    new Date().getTime() - time.hostTime

  _day: (day, hour, minute) ->
    return day + 1 if (minute >= (60 - TIME_INTERVAL)) && (hour == 23)
    return day

  _hour: (hour, minute) ->
    res = if minute >= (60 - TIME_INTERVAL) then hour + 1 else hour
    if res == 24 then 0 else res

  _minute: (minute) ->
    return 0 if minute >= (60 - TIME_INTERVAL)
    Math.ceil(minute / TIME_INTERVAL) * TIME_INTERVAL

  _elapsedTimeInMicroseconds: (start) ->
    startTime = start.getTime()
    endTime =  new Date().getTime()
    diff = new Date(endTime - startTime)
    diff.getTime()

  wrapCounterAndTimerOverMethod: (klass, methodName, sufix = "") =>
    original = klass::[methodName]
    end = @_increaseKeyAndAddTime # Here I need this should be metricsTracker
    klass::[methodName] = (args...) -> # Don't change fat arrow because this should the binded by coffee when construct this
      start = new Date() #  ˅--------------------------------------˄
      res = original.apply(this, args)
      Promise.resolve(res).finally =>
        end("#{klass.name}-#{methodName}-#{sufix}", start)
      res

  wrapCounterOverMethod: (klass, methodName, sufix = "") =>
    original = klass::[methodName]
    end = @_increaseKey # Here I need this should be metricsTracker
    klass::method = (args...) -> # Don't change fat arrow because this should the binded by coffee when construct this
                          #  ˅--------------------------------------˄
      res = original.apply(this, args)
      Promise.resolve(res).finally =>
        end("#{klass.name}-#{methodName}-#{sufix}")
      res

  wrapCounterOverCallback: (klass, methodName, sufix = "") =>
    end = @_increaseKey # Here I need this should be metricsTracker
    @_wrapOverCallback(klass, methodName, sufix, end)

  wrapCounterAndTimerOverCallback: (klass, methodName, sufix = "") =>
    end = @_increaseKeyAndAddTime # Here I need this should be metricsTracker
    @_wrapOverCallback(klass, methodName, sufix, end)

  _wrapOverCallback: (klass, methodName, sufix = "", end) =>
    original = klass::[methodName]
    wrapper = @_wrapCallback
    klass::[methodName] = (args...) ->
      start = new Date()
      context = context or this
      wrapper(args, context, start, end, "#{klass.name}-#{methodName}-#{sufix}")
      original.apply context, args

  _wrapCallback: (args, context, start, end, keyPrefix) ->
    slice = Array::slice
    cb = args.pop()
    timedCb = (args...) ->
      cb.apply context, args
      end(keyPrefix, start)
    args.push timedCb


module.exports = MetricsTracker
