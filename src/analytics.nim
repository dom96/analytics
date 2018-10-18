# Copyright (C) Dominik Picheta. All rights reserved.
# MIT License. Look at license.txt for more info.
import httpclient, asyncdispatch, uri, cgi, strutils, options

import uuids
when defined(windows):
  import osinfo/win
else:
  import osinfo/posix

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

proc createCommonPayload(this: Analytics | AsyncAnalytics,
                         hitType: string): string =
  var payload = "v=1&aip=1&t=" & hitType
  payload.add("&tid=" & encodeUrl(this.tid))
  payload.add("&cid=" & encodeUrl(this.cid))
  payload.add("&an=" & encodeUrl(this.an))
  payload.add("&av=" & encodeUrl(this.av))
  return payload

proc reportEvent*(this: Analytics | AsyncAnalytics, category, action,
                  label: string = "",
                  value: Option[int] = none(int)) {.multiSync.} =

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

  discard await this.client.postContent(collectUrl, body=payload)

proc reportException*(this: Analytics | AsyncAnalytics,
                      description: string, isFatal=true) {.multiSync.} =
  ## Reports an exception to analytics.
  ##
  ## To get this data in analytics, see:
  ## https://stackoverflow.com/a/21718577/492186

  var payload = createCommonPayload(this, "exception")

  payload.add("&exd=" & encodeUrl(description))
  payload.add("&exf=" & $(if isFatal: 1 else: 0))

  discard await this.client.postContent(collectUrl, body=payload)

proc reportTiming*(this: Analytics | AsyncAnalytics, category,
                   name: string, time: int,
                   label: string = "") {.multiSync.} =
  ## Reports timing information to analytics.
  ##
  ## The `time` is specified in miliseconds.
  ##
  ## To get the raw user timings data, see:
  ## https://stackoverflow.com/a/37464695/492186
  var payload = createCommonPayload(this, "timing")

  payload.add("&utc=" & encodeUrl(category))
  payload.add("&utv=" & encodeUrl(name))
  payload.add("&utt=" & $time)
  if label.len > 0:
    payload.add("&utl=" & encodeUrl(label))

  discard await this.client.postContent(collectUrl, body=payload)

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
