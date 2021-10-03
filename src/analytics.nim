# Copyright (C) Dominik Picheta. All rights reserved.
# MIT License. Look at license.txt for more info.
import httpclient, asyncdispatch, uri, cgi, strutils, options

import uuids
when defined(windows):
  import osinfo/win
else:
  import osinfo/posix
import puppy

# Reference: https://goo.gl/BT32cg
type
  AnalyticsRef*[T] = ref object
    client: T
    tid: string ## Tracking ID
    cid: string ## Client ID
    an: string ## Application name
    av: string ## Application version

  Analytics* = AnalyticsRef[HttpClient]
  AsyncAnalytics* = AnalyticsRef[AsyncHttpClient]
  PuppyAnalytics* = AnalyticsRef[puppy.Request]
  AllAnalytics* = Analytics | AsyncAnalytics | PuppyAnalytics

const
  collectUrl = "https://www.google-analytics.com/collect"

proc newAnalyticsRef[T](trackingID, clientID, appName, appVer: string,
                        userAgent = "", proxy: Proxy = nil): AnalyticsRef[T] =
  var ua = userAgent
  if ua.len == 0:
    # We gather some OS stats here to include in the user agent.
    when defined(windows):
      let systemVersion = $getVersionInfo()
    else:
      let systemVersion = getSystemVersion()

    ua = "$1/$2 ($3) (Built with Nim v$4)" % [
      appName, appVer, systemVersion, NimVersion
    ]

  result = AnalyticsRef[T](
    client:
      when T is HttpClient: newHttpClient(userAgent = ua, proxy = proxy)
      elif T is puppy.Request: puppy.newRequest(collectUrl, "post",  @[Header(key: "User-Agent", value: ua)])
      else: newAsyncHttpClient(userAgent = ua, proxy = proxy),
    tid: trackingID,
    cid: clientID,
    an: appName,
    av: appVer
  )

proc newAnalytics*(trackingID, clientID, appName, appVer: string,
                   userAgent = "", proxy: Proxy = nil): Analytics =
  ## Creates a new analytics reporting object.
  ##
  ## When `userAgent` is empty, one is created based on the current OS info.
  return newAnalyticsRef[HttpClient](trackingID, clientID, appName, appVer,
                                     userAgent, proxy)

proc newAsyncAnalytics*(trackingID, clientID, appName, appVer: string,
                        userAgent = "", proxy: Proxy = nil): AsyncAnalytics =
  ## Creates a new async analytics reporting object.
  ##
  ## When `userAgent` is empty, one is created based on the current OS info.
  return newAnalyticsRef[AsyncHttpClient](trackingID, clientID, appName, appVer,
                                          userAgent, proxy)

proc newPuppyAnalytics*(trackingID, clientID, appName, appVer: string,
                        userAgent = "", proxy: Proxy = nil,
                        timeout=5.0): PuppyAnalytics =
  ## Creates a new puppy analytics reporting object.
  ##
  ## When `userAgent` is empty, one is created based on the current OS info.
  ##
  ## The timeout is in seconds.
  result = newAnalyticsRef[puppy.Request](trackingID, clientID, appName, appVer,
                                          userAgent, proxy)
  result.client.timeout = timeout

proc createCommonPayload(this: AllAnalytics,
                         hitType: string): string =
  var payload = "v=1&aip=1&t=" & hitType
  payload.add("&tid=" & encodeUrl(this.tid))
  payload.add("&cid=" & encodeUrl(this.cid))
  payload.add("&an=" & encodeUrl(this.an))
  payload.add("&av=" & encodeUrl(this.av))
  return payload

proc createEventPayload(this: AllAnalytics, category, action,
  label: string, value: Option[int]
): string =
  if category.len == 0:
    raise newException(ValueError, "Category cannot be empty.")

  if action.len == 0:
    raise newException(ValueError, "Action cannot be empty.")

  var payload = createCommonPayload(this, "event")

  payload.add("&ec=" & encodeUrl(category))
  payload.add("&ea=" & encodeUrl(action))
  if label.len > 0:
    payload.add("&el=" & encodeUrl(label))
  if value.isSome:
    payload.add("&ev=" & $value.get())
  return payload

proc reportEvent*(this: Analytics | AsyncAnalytics, category, action,
                  label: string = "",
                  value: Option[int] = none(int)) {.multiSync.} =
  let payload = createEventPayload(this, category, action, label, value)
  discard await this.client.postContent(collectUrl, body=payload)

proc reportEvent*(this: PuppyAnalytics, category, action,
                  label: string = "",
                  value: Option[int] = none(int)) =
  let payload = createEventPayload(this, category, action, label, value)
  this.client.body = payload
  if fetch(this.client).code != Http200.int:
    raise newException(ValueError, "Got non-200 response from analytics endpoint.")

proc createExceptionPayload(
  this: AllAnalytics, description: string, isFatal: bool
): string =
  var payload = createCommonPayload(this, "exception")

  payload.add("&exd=" & encodeUrl(description))
  payload.add("&exf=" & $(if isFatal: 1 else: 0))
  return payload

proc reportException*(this: Analytics | AsyncAnalytics,
                      description: string, isFatal=true) {.multiSync.} =
  ## Reports an exception to analytics.
  ##
  ## To get this data in analytics, see:
  ## https://stackoverflow.com/a/21718577/492186
  let payload = createExceptionPayload(this, description, isFatal)
  discard await this.client.postContent(collectUrl, body=payload)

proc reportException*(this: PuppyAnalytics,
                      description: string, isFatal=true) =
  ## Reports an exception to analytics.
  ##
  ## To get this data in analytics, see:
  ## https://stackoverflow.com/a/21718577/492186
  let payload = createExceptionPayload(this, description, isFatal)
  this.client.body = payload
  if fetch(this.client).code != Http200.int:
    raise newException(ValueError, "Got non-200 response from analytics endpoint.")

proc createTimingPayload(
  this: AllAnalytics, category, name: string, time: int, label: string = ""
): string =
  var payload = createCommonPayload(this, "timing")

  payload.add("&utc=" & encodeUrl(category))
  payload.add("&utv=" & encodeUrl(name))
  payload.add("&utt=" & $time)
  if label.len > 0:
    payload.add("&utl=" & encodeUrl(label))
  return payload

proc reportTiming*(this: Analytics | AsyncAnalytics, category,
                   name: string, time: int,
                   label: string = "") {.multiSync.} =
  ## Reports timing information to analytics.
  ##
  ## The `time` is specified in miliseconds.
  ##
  ## To get the raw user timings data, see:
  ## https://stackoverflow.com/a/37464695/492186
  let payload = createTimingPayload(this, category, name, time, label)
  discard await this.client.postContent(collectUrl, body=payload)

proc reportTiming*(this: PuppyAnalytics, category,
                   name: string, time: int,
                   label: string = "") =
  let payload = createTimingPayload(this, category, name, time, label)
  this.client.body = payload
  if fetch(this.client).code != Http200.int:
    raise newException(ValueError, "Got non-200 response from analytics endpoint.")

proc genClientID*(): string =
  return $genUUID()

when isMainModule:
  let tid = "UA-105812497-2"
  let cid = genClientID()
  let analytics = newAnalytics(tid, cid, "AnalyticsTester", "0.1")
  analytics.reportEvent("InstallSuccess", "nim c analytics", "", some(4567))
  analytics.reportEvent("InstallFailure", "nim c analytics",
                        "Error: .... hello lorem ipsum dolor sit amet",
                        some(1234))
