-- =============================================================================
-- sessions.sql — Phase 2
-- =============================================================================
-- A session represents a single whiteboard that users can join and collaborate on.
--
-- Design Decisions:
--
-- 1. PRIMARY KEY: UUID vs SERIAL
--    Using UUID because:
--    - Can be generated client-side (no round-trip to get an ID)
--    - Safe for distributed systems / offline-first
--    - No information leakage (can't guess session IDs)
--    - Trade-off: Larger storage, slightly slower indexes
--
-- 2. COLUMNS: Explicit vs JSON
--    Using explicit columns because:
--    - `name` is frequently queried/displayed
--    - `created_at` is sortable/indexable
--    - No need for schema flexibility here
--
-- 3. TIMESTAMPS: TIMESTAMPTZ
--    Always use TIMESTAMPTZ (not TIMESTAMP) to store timezone-aware values.
--    Postgres stores everything in UTC internally.
--
-- 4. FUTURE RELATIONSHIPS:
--    - shapes.session_id → sessions.id (one-to-many)
--    - session_members.session_id → sessions.id (if we track membership)
-- =============================================================================

CREATE TABLE sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- =============================================================================
-- COMMENTS
-- =============================================================================
-- Document the table for future reference (shows up in Supabase dashboard)

COMMENT ON TABLE sessions IS 'Whiteboard sessions that users can join';
COMMENT ON COLUMN sessions.id IS 'Unique identifier, generated client or server side';
COMMENT ON COLUMN sessions.name IS 'Human-readable session name';
COMMENT ON COLUMN sessions.created_at IS 'When the session was created';
COMMENT ON COLUMN sessions.updated_at IS 'When the session was last modified';

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================
-- Enable RLS but don't create policies yet.
-- Without policies, the table is completely locked down.
-- This is intentional — you'll add policies when you need them.

ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- EXAMPLE POLICY (for reference, commented out)
-- =============================================================================
-- Allow anyone to read sessions (public whiteboards):
--
-- CREATE POLICY "Sessions are viewable by everyone"
--   ON sessions FOR SELECT
--   USING (true);
--
-- Allow anyone to create sessions:
--
-- CREATE POLICY "Anyone can create sessions"
--   ON sessions FOR INSERT
--   WITH CHECK (true);

