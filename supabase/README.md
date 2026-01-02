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

## Phase 2 — Tables & Data Modeling

### Key Questions When Designing for Realtime

Before creating any table, ask yourself:

1. **What gets updated frequently vs rarely?**
   - Frequent updates = consider splitting into separate tables
   - Rare updates = can keep in same table

2. **Do I need to query individual fields?**
   - Yes → use explicit columns
   - No, and schema varies → consider JSONB

3. **Will this table be realtime-enabled?**
   - Yes → every row change broadcasts the entire row
   - Consider the payload size

### The Sessions Table

See `schema/sessions.sql` for the complete definition with comments.

**Summary:**

```sql
CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

**Why UUID?**
- Generated client-side (no round-trip needed)
- No information leakage (can't guess IDs)
- Works in distributed/offline scenarios

**Why explicit columns (not JSON)?**
- `name` is queryable, sortable, indexable
- Schema is stable — sessions always have these fields

### Running the SQL

In the Supabase Dashboard:

1. Go to **SQL Editor**
2. Paste the contents of `schema/sessions.sql`
3. Click **Run**

Or via CLI:

```bash
psql "postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres" \
  -f supabase/schema/sessions.sql
```

### Phase 2 TODOs

- [ ] Run `schema/sessions.sql` in Supabase SQL Editor
- [ ] Design the `shapes` table
- [ ] Decide: columns vs JSON for shape properties (width, height, x, y, color, rotation)
- [ ] Justify each design decision in comments

**Questions to answer in your design:**

| Question | Think About... |
|----------|----------------|
| What's the primary key? | UUID? Same reasoning as sessions? |
| How do shapes relate to sessions? | Foreign key to `sessions.id`? |
| What shape types exist? | Rectangle, circle, line — same columns or different? |
| Which properties change often? | Position? Size? Color? |
| Will you query by shape properties? | "Find all red shapes"? Probably not. |

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
