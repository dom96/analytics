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
  Analytics* = ref object
    client: HttpClient
    tid: string ## Tracking ID
    cid: string ## Client ID
    an: string ## Application name
    av: string ## Application version

const
  collectUrl = "https://www.google-analytics.com/collect"

proc newAnalytics*(trackingID, clientID, appName, appVer: string,
                   userAgent = ""): Analytics =
  ## Creates a new analytics reporting object.
  ##
  ## When `userAgent` is empty, one is created based on the current OS info.
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

  result = Analytics(
    client: newHttpClient(userAgent = ua),
    tid: trackingID,
    cid: clientID,
    an: appName,
    av: appVer
  )

proc createCommonPayload(this: Analytics, hitType: string): string =
  var payload = "v=1&aip=1&t=" & hitType
  payload.add("&tid=" & encodeUrl(this.tid))
  payload.add("&cid=" & encodeUrl(this.cid))
  payload.add("&an=" & encodeUrl(this.an))
  payload.add("&av=" & encodeUrl(this.av))
  return payload

proc reportEvent*(this: Analytics, category, action, label: string = "",
                  value: Option[int] = none(int)) =

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

  discard this.client.postContent(collectUrl, body=payload)

proc reportException*(this: Analytics, description: string, isFatal=true) =
  ## Reports an exception to analytics.
  ##
  ## To get this data in analytics, see:
  ## https://stackoverflow.com/a/21718577/492186

  var payload = createCommonPayload(this, "exception")

  payload.add("&exd=" & encodeUrl(description))
  payload.add("&exf=" & $(if isFatal: 1 else: 0))

  discard this.client.postContent(collectUrl, body=payload)

proc reportTiming*(this: Analytics, category, name: string, time: int,
                   label: string = "") =
  ## Reports timing information to analytics.
  var payload = createCommonPayload(this, "timing")
  
  payload.add("&utc=" & encodeUrl(category))
  payload.add("&utv=" & encodeUrl(name))
  payload.add("&utt=" & $time)
  if label.len > 0:
    payload.add("&utl=" & encodeUrl(label))

  discard this.client.postContent(collectUrl, body=payload)

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