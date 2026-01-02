create table shapes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL REFERENCES sessions(id),
    shape_type SHAPE_TYPE NOT NULL,
    height FLOAT NOT NULL,
    width FLOAT NOT NULL,
    x FLOAT NOT NULL,
    y FLOAT NOT NULL,
    color TEXT NOT NULL,
    rotation FLOAT NOT NULL,
    text TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

COMMENT ON TABLE shapes IS 'Shapes that users can create on the whiteboard';
COMMENT ON COLUMN shapes.id IS 'Unique identifier, generated client or server side';
COMMENT ON COLUMN shapes.session_id IS 'Session ID that the shape belongs to';
COMMENT ON COLUMN shapes.shape_type IS 'Type of shape (rectangle, circle, triangle, text)';
COMMENT ON COLUMN shapes.height IS 'Height of the shape';
COMMENT ON COLUMN shapes.width IS 'Width of the shape';
COMMENT ON COLUMN shapes.x IS 'X position of the shape';
COMMENT ON COLUMN shapes.y IS 'Y position of the shape';
COMMENT ON COLUMN shapes.color IS 'Color of the shape';
COMMENT ON COLUMN shapes.rotation IS 'Rotation of the shape';
COMMENT ON COLUMN shapes.text IS 'Text of the shape';
COMMENT ON COLUMN shapes.created_at IS 'When the shape was created';
COMMENT ON COLUMN shapes.updated_at IS 'When the shape was last updated';

ALTER TABLE shapes ENABLE ROW LEVEL SECURITY;

ALTER PUBLICATION supabase_realtime ADD TABLE shapes;
