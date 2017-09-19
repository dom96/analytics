# Analytics

A Nim library for reporting events on Google Analytics.

## Usage

In your .nimble file:

```nim
requires "analytics"
```

In your Nim source code:

```nim
import analytics

let tid = "<YourAnalyticsTrackingId>"
let cid = genClientID() # Only generate this once per user!
let analytics = newAnalytics(tid, cid, "AnalyticsTester", "v0.1")
analytics.reportEvent("AnalyticsTest", "Hello", "", "")
```