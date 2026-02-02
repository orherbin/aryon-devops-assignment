-- Items table
CREATE TABLE IF NOT EXISTS items (
    id UUID PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create index on created_at for efficient ordering
CREATE INDEX IF NOT EXISTS idx_items_created_at ON items(created_at DESC);

-- Audit logs table
CREATE TABLE IF NOT EXISTS audit_logs (
    id SERIAL PRIMARY KEY,
    action VARCHAR(100) NOT NULL,
    details JSONB,
    timestamp TIMESTAMP NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);

-- Insert some sample data (optional, for testing)
-- Uncomment to include sample data
-- INSERT INTO items (id, name, description) VALUES 
--     ('550e8400-e29b-41d4-a716-446655440000'::UUID, 'Sample Item 1', 'This is a sample item for testing'),
--     ('550e8400-e29b-41d4-a716-446655440001'::UUID, 'Sample Item 2', 'Another sample item');
