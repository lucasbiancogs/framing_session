# Supabase Realtime — Core Concepts

This document explains the three distinct realtime tools in Supabase and when to use each one.

---

## The Big Picture

Supabase Realtime is not one thing — it's **three separate tools** that solve different problems:

|            Tool             |          What It Does         |           Persistence         |     Source of Truth    |
|-----------------------------|-------------------------------|-------------------------------|------------------------|
| **Database Realtime (CDC)** | Streams database changes      | Permanent (rows in Postgres)  | The database           |
|        **Presence**         | Tracks who is connected       | Ephemeral (memory only)       | The channel state      |
|        **Broadcast**        | Sends messages to subscribers | None                          | None (fire-and-forget) |

Understanding which tool to use is the key to building correct realtime applications.

---

## Mental Model: The Whiteboard Analogy

Imagine a collaborative whiteboard application:

```
┌─────────────────────────────────────────────────────────────────┐
│                        WHITEBOARD APP                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   ┌─────────────┐                                               │
│   │   Shapes    │  ← Must persist. If I refresh, shapes stay.   │
│   │  (Database) │    Uses: Database Realtime (CDC)              │
│   └─────────────┘                                               │
│                                                                 │
│   ┌─────────────┐                                               │
│   │  User List  │  ← Who's here NOW. Gone when they leave.      │
│   │ (Presence)  │    Uses: Presence                             │
│   └─────────────┘                                               │
│                                                                 │
│   ┌─────────────┐                                               │
│   │   Cursors   │  ← High-frequency, loss is OK.                │
│   │ (Broadcast) │    Uses: Broadcast                            │
│   └─────────────┘                                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Tool 1: Database Realtime (CDC)

### What It Is

**Change Data Capture** — Supabase listens to your Postgres database and emits events when rows are inserted, updated, or deleted.

### How It Works

```
┌──────────────┐      INSERT/UPDATE/DELETE      ┌──────────────┐
│   Client A   │  ─────────────────────────────▶│   Postgres   │
└──────────────┘                                └──────┬───────┘
                                                       │
                                                       │ CDC Event
                                                       ▼
                                                ┌──────────────┐
                                                │   Realtime   │
                                                │    Server    │
                                                └──────┬───────┘
                                                       │
                              ┌─────────────────┬──────┴──────┬─────────────────┐
                              ▼                 ▼             ▼                 ▼
                        ┌──────────┐      ┌──────────┐  ┌──────────┐      ┌──────────┐
                        │ Client A │      │ Client B │  │ Client C │      │ Client D │
                        └──────────┘      └──────────┘  └──────────┘      └──────────┘
```

### Key Characteristics

- **Source of truth is the database** — The row exists, therefore it's real
- **Persistence is permanent** — Data survives server restarts, client disconnects
- **Payload contains row data** — You receive the actual column values
- **Requires table configuration** — Must enable realtime on specific tables

### When to Use

✅ Shape creation and updates  
✅ Session metadata  
✅ Any data that must survive a page refresh  
✅ Data that needs to be queried later  

### When NOT to Use

❌ High-frequency updates (cursor positions) — Too much database load  
❌ Transient state (typing indicators) — Doesn't need persistence  
❌ "Who's online" lists — Presence is purpose-built for this  

### Event Types

|  Event   |        Trigger        |
|----------|-----------------------|
| `INSERT` | New row created       |
| `UPDATE` | Existing row modified |
| `DELETE` | Row removed           |

---

## Tool 2: Presence

### What It Is

**Presence** tracks which users are currently connected to a channel and what state they have shared.

### How It Works

```
┌──────────────┐                                ┌──────────────┐
│   Client A   │ ───── track(my_state) ────────▶│   Channel    │
└──────────────┘                                │   "room:1"   │
                                                │              │
┌──────────────┐                                │  Presence:   │
│   Client B   │ ───── track(my_state) ────────▶│  - Client A  │
└──────────────┘                                │  - Client B  │
                                                │  - Client C  │
┌──────────────┐                                │              │
│   Client C   │ ───── track(my_state) ────────▶│              │
└──────────────┘                                └──────┬───────┘
                                                       │
                                                       │ sync/join/leave events
                                                       ▼
                                                  All Clients
```

### Key Characteristics

- **Ephemeral by design** — State is gone when the user disconnects
- **Automatic cleanup** — No need to manually remove users
- **Syncs across all subscribers** — Everyone sees the same presence state
- **Custom state per user** — Each user can share metadata (name, color, etc.)

### Events

|  Event  |        When It Fires        |
|---------|-----------------------------|
| `sync`  | Initial state when you join |
| `join`  | A new user connects         |
| `leave` | A user disconnects          |

### When to Use

✅ "Who's online" user lists  
✅ User avatars in the corner of the canvas  
✅ "X is typing..." indicators  
✅ Any "currently connected" state  

### When NOT to Use

❌ Data that must persist after disconnect  
❌ High-frequency position updates (use Broadcast)  
❌ Historical data ("who was here yesterday")  

### Presence State Example

Each user tracks their own state:

```
{
  "user_id": "abc123",
  "name": "Alice",
  "color": "#FF5733",
  "joined_at": "2024-01-15T10:30:00Z"
}
```

All clients receive a merged view of everyone's state.

---

## Tool 3: Broadcast

### What It Is

**Broadcast** sends ephemeral messages to all subscribers on a channel. Think of it as a "fire-and-forget" pipe.

### How It Works

```
┌──────────────┐                                ┌──────────────┐
│   Client A   │ ───── broadcast(event) ───────▶│   Channel    │
└──────────────┘                                │   "room:1"   │
                                                └──────┬───────┘
                                                       │
                              ┌─────────────────┬──────┴──────┬─────────────────┐
                              ▼                 ▼             ▼                 ▼
                        ┌──────────┐      ┌──────────┐  ┌──────────┐      ┌──────────┐
                        │ Client A │      │ Client B │  │ Client C │      │ Client D │
                        │ (sender) │      │          │  │          │      │ (offline)│
                        └──────────┘      └──────────┘  └──────────┘      └──────────┘
                             ✓                 ✓             ✓                 ✗
                                                                          (missed it)
```

### Key Characteristics

- **No persistence** — Messages are not stored anywhere
- **No delivery guarantee** — If a client is offline, they miss it
- **No source of truth** — The message exists only in transit
- **Extremely lightweight** — No database writes, no storage

### When to Use

✅ Cursor movement (30-60 updates/second)  
✅ Drawing strokes in progress  
✅ Temporary visual feedback  
✅ Any high-frequency, loss-tolerant update  

### When NOT to Use

❌ Data that must not be lost  
❌ State that needs to survive reconnection  
❌ Anything you'd need to query later  

### Broadcast Payload Example

```
{
  "type": "cursor_move",
  "user_id": "abc123",
  "x": 450,
  "y": 320,
  "timestamp": 1705312200000
}
```

---

## Comparison Matrix

|          Aspect        | Database CDC  |     Presence     |    Broadcast    |
|------------------------|---------------|------------------|-----------------|
| **Persistence**        | Permanent     | Until disconnect | None            |
| **Source of Truth**    | Postgres rows | Channel state    | None            |
| **Delivery Guarantee** | Yes (via DB)  | Yes (via sync)   | No              |
| **Use Case**           | Shape data    | User list        | Cursor movement |
| **Frequency**          | Low-Medium    | Low              | High            |
| **Database Load**      | Yes           | No               | No              |

---

## The Critical Question

Before using any realtime feature, ask:

> **"What happens if a client reconnects after missing updates?"**

|       Tool       |                     Answer                      |
|------------------|-------------------------------------------------|
| **Database CDC** | Client queries the database — all data is there |
| **Presence**     | Client receives `sync` event with current state |
| **Broadcast**    | Client missed the messages — they're gone       |

This is why:
- **Shapes** → Database (must be recoverable)
- **User list** → Presence (sync rebuilds it)
- **Cursors** → Broadcast (stale positions are meaningless anyway)

---

## Common Mistakes

### Mistake 1: Using Database for Cursors

```
❌ INSERT INTO cursor_positions (user_id, x, y) VALUES (...)
   UPDATE cursor_positions SET x = ..., y = ... WHERE user_id = ...
```

**Why it's wrong:** 30-60 writes/second per user. Database will choke.

**Correct:** Use Broadcast. Missed cursor positions don't matter.

### Mistake 2: Using Broadcast for Shapes

```
❌ channel.send({ type: 'shape_created', shape: {...} })
```

**Why it's wrong:** If a client joins late, they never see the shape.

**Correct:** Use Database CDC. Query on join, stream updates after.

### Mistake 3: Using Database for "Who's Online"

```
❌ UPDATE users SET is_online = true WHERE id = ...
   -- With a cron job to mark stale users as offline
```

**Why it's wrong:** Complex, unreliable, doesn't handle crashes.

**Correct:** Use Presence. Automatic cleanup on disconnect.

---

## Decision Flowchart

```
                    ┌─────────────────────────────┐
                    │  Must data survive refresh? │
                    └──────────────┬──────────────┘
                                   │
                      ┌────────────┴────────────┐
                      │                         │
                     YES                        NO
                      │                         │
                      ▼                         ▼
               ┌──────────────┐      ┌─────────────────────────┐
               │ Database CDC │      │ Is it "who's connected"?│
               └──────────────┘      └────────────┬────────────┘
                                                  │
                                     ┌────────────┴────────────┐
                                     │                         │
                                    YES                        NO
                                     │                         │
                                     ▼                         ▼
                              ┌──────────┐              ┌───────────┐
                              │ Presence │              │ Broadcast │
                              └──────────┘              └───────────┘
```

---

## Summary

| Feature in Whiteboard App |     Tool     |             Reason                |
|---------------------------|--------------|-----------------------------------|
| Shape creation            | Database CDC | Must persist, must be queryable   |
| Shape property updates    | Database CDC | Must persist                      |
| Session metadata          | Database CDC | Must persist                      |
| User list ("who's here")  | Presence     | Only care about NOW, auto-cleanup |
| User colors/names         | Presence     | Tied to connection lifetime       |
| Cursor movement           | Broadcast    | High frequency, loss is OK        |
| Drawing in progress       | Broadcast    | Transient visual feedback         |

---

## Next Steps (Your TODOs)

After reading this document:

1. **Write your own explanations** — In your own words, explain each tool
2. **Map your features** — For each feature you'll build, decide which tool fits
3. **Draw a data flow** — Sketch how data moves through your system

