---
inclusion: auto
name: data-ingest
description: Scheduled jobs and data ingest - EventBridge Scheduler, cron or rate schedules, timezone, daylight saving, scraper, polling an external or upstream API, cursor, idempotent upserts, backfill history, upstream data lag, retries, Lambda concurrency and reserved concurrency, overlapping runs. Use when building or debugging a scheduled job or data pull.
---
<!-- kiro-template v2.0.0 -->

# Scheduled Jobs and Data Ingest

- **EventBridge Scheduler** with `ScheduleExpressionTimezone` set (e.g.
  `Europe/London`); otherwise cron runs in UTC and drifts an hour across DST.
- **Right-size schedules**: run only as often as the data changes or is seen.
- **Idempotent, cursor-based ingest**: a "fetched up to" cursor per source,
  re-fetch a small overlap, upsert so reruns never duplicate. Upstream APIs lag
  and have gaps: show "data up to <time>" in the UI.
- **Backfill mode** in its own script, never automatic: loads history in bounded
  chunks (e.g. month by month).
- `MaximumRetryAttempts: 0` when the next run self-heals.
- **No `ReservedConcurrentExecutions` by default**: small/new accounts can have a
  quota of 50 and Lambda keeps 50 unreserved, so any reservation fails at deploy.
  Prevent overlap with idempotent writes or a DynamoDB conditional-write lock.
