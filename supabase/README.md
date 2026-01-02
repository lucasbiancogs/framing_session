# Supabase

This folder contains all Supabase-related documentation, schemas, and realtime concepts.

## Structure

```
supabase/
├── README.md          # This file
├── schema/            # SQL table definitions
│   └── sessions.sql   # (Phase 2+)
├── realtime/          # Realtime feature documentation
│   ├── presence.md    # Presence concepts and examples
│   └── broadcast.md   # Broadcast concepts and examples
└── notes/
    └── concepts.md    # Core realtime taxonomy
```

---

## Project Setup (Phase 1)

### 1. Create a Supabase Project

1. Go to [supabase.com](https://supabase.com)
2. Click **New Project**
3. Choose an organization (or create one)
4. Set a **database password** (save this somewhere secure)
5. Select a **region** close to you
6. Wait for the project to initialize (~2 minutes)

### 2. Get Your Credentials

Go to **Project Settings → API**:

| Field        | Where to Find                              |
|--------------|--------------------------------------------|
| Project URL  | `https://xxx.supabase.co`                  |
| Anon Key     | Under "Project API keys" → `anon` `public` |

### 3. Test the Connection

In your Flutter app:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

If the app starts without an exception, Supabase is connected.

---

## Security Note

The **anon key** is designed to be public. It's embedded in client apps and visible to anyone who decompiles them.

**This is safe IF** you enable Row Level Security (RLS) on all tables:

```sql
-- Enable RLS
ALTER TABLE your_table ENABLE ROW LEVEL SECURITY;

-- Without policies, NO ONE can access the table (not even with anon key)
-- You must create explicit policies to allow access
```

The **service_role key** is **secret** and should NEVER be in client code. It bypasses RLS entirely.

---

## Phases

| Phase | What's Added                           |
|-------|----------------------------------------|
| 0     | `notes/concepts.md` — Mental model     |
| 1     | Project setup instructions             |
| 2     | `schema/sessions.sql` — First table    |
| 3     | Database realtime (CDC)                |
| 5     | `realtime/presence.md`                 |
| 6     | `realtime/broadcast.md`                |
