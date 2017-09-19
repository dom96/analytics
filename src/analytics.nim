# Copyright (C) Dominik Picheta. All rights reserved.
# MIT License. Look at license.txt for more info.
import httpclient, asyncdispatch, uri, cgi

import uuids

# Reference: https://goo.gl/BT32cg
type
  Analytics* = ref object
    client: HttpClient
    tid: string ## Tracking ID
    cid: string ## Client ID
    an: string ## Application name
    av: string ## Application version

proc newAnalytics*(trackingID, clientID, appName, appVer: string): Analytics =
  Analytics(
    client: newHttpClient(),
    tid: trackingID,
    cid: clientID,
    an: appName,
    av: appVer
  )

proc reportEvent*(this: Analytics, category, action, label,
                  value: string) =
  var uri = parseUri("https://www.google-analytics.com/collect")

  # var data = newMultipartData()
  # data["v"] = "1"
  # data["aip"] = "1"
  # data["t"] = "event"

  # data["tid"] = this.tid
  # data["cid"] = this.cid
  # data["an"] = this.an
  # data["av"] = this.av

  # data["ec"] = category
  # data["ea"] = action
  # data["el"] = label
  # data["ev"] = value

  if category.len == 0:
    raise newException(ValueError, "Category cannot be empty.")

  if action.len == 0:
    raise newException(ValueError, "Action cannot be empty.")

  var payload = "v=1&aip=1&t=event"
  payload.add("&tid=" & encodeUrl(this.tid))
  payload.add("&cid=" & encodeUrl(this.cid))
  payload.add("&an=" & encodeUrl(this.an))
  payload.add("&av=" & encodeUrl(this.av))

  payload.add("&ec=" & encodeUrl(category))
  payload.add("&ea=" & encodeUrl(action))
  if label.len > 0:
    payload.add("&el=" & encodeUrl(label))
  if value.len > 0:
    payload.add("&ev=" & encodeUrl(value))

  echo this.client.postContent($uri, body=payload)

proc genClientID*(): string =
  return $genUUID()

when isMainModule:
  let tid = "UA-105812497-2"
  let cid = genClientID()
  let analytics = newAnalytics(tid, cid, "AnalyticsTester", "0.1")
  analytics.reportEvent("AnalyticsTest", "nim c analytics", "", "")