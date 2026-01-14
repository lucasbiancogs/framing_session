create table connectors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id),
    source_shape_id UUID NOT NULL REFERENCES shapes(id) ON DELETE CASCADE,
    target_shape_id UUID NOT NULL REFERENCES shapes(id) ON DELETE CASCADE,
    source_anchor TEXT NOT NULL,
    target_anchor TEXT NOT NULL,
    arrow_type ARROW_TYPE NOT NULL DEFAULT 'end',
    color TEXT NOT NULL DEFAULT '#FFFFFF',
    waypoints JSONB,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE connectors IS 'Connectors that link shapes on the whiteboard';
COMMENT ON COLUMN connectors.id IS 'Unique identifier, generated client or server side';
COMMENT ON COLUMN connectors.session_id IS 'Session ID that the connector belongs to';
COMMENT ON COLUMN connectors.source_shape_id IS 'Shape ID where the connector starts';
COMMENT ON COLUMN connectors.target_shape_id IS 'Shape ID where the connector ends';
COMMENT ON COLUMN connectors.source_anchor IS 'Anchor point on source shape (top, right, bottom, left)';
COMMENT ON COLUMN connectors.target_anchor IS 'Anchor point on target shape (top, right, bottom, left)';
COMMENT ON COLUMN connectors.arrow_type IS 'Arrow direction (none, start, end, both)';
COMMENT ON COLUMN connectors.color IS 'Color of the connector line';
COMMENT ON COLUMN connectors.waypoints IS 'User-adjusted intermediate points as JSON array of {x, y}';
COMMENT ON COLUMN connectors.created_at IS 'When the connector was created';
COMMENT ON COLUMN connectors.updated_at IS 'When the connector was last updated';

ALTER TABLE connectors ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read connectors
CREATE POLICY "Connectors are viewable by everyone"
  ON connectors FOR SELECT
  USING (true);

-- Allow anyone to create connectors
CREATE POLICY "Anyone can create connectors"
  ON connectors FOR INSERT
  WITH CHECK (true);

-- Allow anyone to delete connectors
CREATE POLICY "Anyone can delete connectors"
  ON connectors FOR DELETE
  USING (true);

-- Allow anyone to update connectors
CREATE POLICY "Anyone can update connectors"
  ON connectors FOR UPDATE
  USING (true);

ALTER PUBLICATION supabase_realtime ADD TABLE connectors;

