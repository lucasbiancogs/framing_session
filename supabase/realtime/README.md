# Supabase Realtime — Database CDC

## Overview

Database Realtime (Change Data Capture) streams row-level changes from Postgres to connected clients.

**Source of Truth**: The database itself.

**Persistence**: Permanent — data survives reconnection.

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                         Postgres                                │
│  ┌─────────────────┐                                           │
│  │    sessions     │ ──INSERT/UPDATE/DELETE──┐                 │
│  └─────────────────┘                         │                 │
│  ┌─────────────────┐                         ▼                 │
│  │     shapes      │ ──────────────► supabase_realtime         │
│  └─────────────────┘                 (publication)             │
└──────────────────────────────────────────────┬──────────────────┘
                                               │
                                               ▼
                                    ┌──────────────────┐
                                    │ Supabase Server  │
                                    │   (broadcasts)   │
                                    └────────┬─────────┘
                                             │
              ┌──────────────────────────────┼──────────────────────┐
              ▼                              ▼                      ▼
        ┌──────────┐                  ┌──────────┐           ┌──────────┐
        │ Client A │                  │ Client B │           │ Client C │
        └──────────┘                  └──────────┘           └──────────┘
```

---

## Enabling Realtime on a Table

```sql
-- Add table to the realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE sessions;
```

This tells Postgres: "Broadcast changes to `sessions` to all subscribers."

---

## Payload Structure

When a row changes, Supabase sends this JSON structure:

### INSERT

```json
{
  "type": "INSERT",
  "table": "sessions",
  "schema": "public",
  "record": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "My Whiteboard",
    "created_at": "2026-01-02T12:00:00Z",
    "updated_at": "2026-01-02T12:00:00Z"
  },
  "old_record": null
}
```

### UPDATE

```json
{
  "type": "UPDATE",
  "table": "sessions",
  "schema": "public",
  "record": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "Renamed Whiteboard",
    "created_at": "2026-01-02T12:00:00Z",
    "updated_at": "2026-01-02T12:05:00Z"
  },
  "old_record": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "name": "My Whiteboard",
    "created_at": "2026-01-02T12:00:00Z",
    "updated_at": "2026-01-02T12:00:00Z"
  }
}
```

### DELETE

```json
{
  "type": "DELETE",
  "table": "sessions",
  "schema": "public",
  "record": null,
  "old_record": {
    "id": "550e8400-e29b-41d4-a716-446655440000"
  }
}
```

> **Note**: For DELETE, `old_record` only includes the primary key by default. Enable `REPLICA IDENTITY FULL` to get all columns.

---

## Event Types

| Event    | Trigger               | `record`     | `old_record`        |
|----------|-----------------------|--------------|---------------------|
| INSERT   | New row created       | New row data | `null`              |
| UPDATE   | Existing row modified | New row data | Previous row data   |
| DELETE   | Row removed           | `null`       | Primary key (or full row) |

---

## When to Use CDC

| Use Case                | CDC? | Why                                           |
|-------------------------|------|-----------------------------------------------|
| Shape created           | ✅   | Must persist — refresh should show it         |
| Shape position changed  | ✅   | Change must be permanent                      |
| Session renamed         | ✅   | Needs to survive reconnection                 |
| Cursor position         | ❌   | 30-60 updates/sec — use Broadcast instead     |
| Who's online            | ❌   | Ephemeral data — use Presence instead         |

---

## Performance Considerations

1. **Every subscriber gets every change**  
   If 100 clients subscribe and you INSERT 1 row, 100 payloads go out.

2. **Large payloads = more bandwidth**  
   If your row has many columns, each change sends the full row (unless filtered).

3. **High-frequency updates are expensive**  
   If a shape's position changes 60 times/second, that's 60 × N clients × payload size.  
   Consider Broadcast for high-frequency, low-importance updates.

---

## What's NOT Covered Here

- **Flutter listeners** — handled in Phase 4
- **Filtering by columns** — advanced feature
- **Row-level filters** — subscribing to specific rows only

