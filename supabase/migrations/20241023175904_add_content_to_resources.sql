-- supabase/migrations/20241023175904_add_content_to_resources.sql

-- Add content column to resources table
ALTER TABLE resources 
ADD COLUMN IF NOT EXISTS content TEXT;

-- Make sure we have the vector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create embeddings table if it doesn't exist
CREATE TABLE IF NOT EXISTS embeddings (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::TEXT,
    resource_id TEXT NOT NULL REFERENCES resources(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    embedding VECTOR(1536) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index for vector similarity search
CREATE INDEX IF NOT EXISTS embeddings_embedding_idx ON embeddings 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Create or replace the match_documents function
CREATE OR REPLACE FUNCTION match_documents(
    query_embedding VECTOR(1536),
    match_threshold FLOAT,
    match_count INT
)
RETURNS TABLE (
    id TEXT,
    content TEXT,
    similarity FLOAT
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        e.resource_id,
        e.content,
        1 - (e.embedding <=> query_embedding) AS similarity
    FROM embeddings e
    WHERE 1 - (e.embedding <=> query_embedding) > match_threshold
    ORDER BY e.embedding <=> query_embedding
    LIMIT match_count;
END;
$$;

-- Grant necessary permissions
GRANT ALL ON TABLE resources TO service_role;
GRANT ALL ON TABLE embeddings TO service_role;
GRANT EXECUTE ON FUNCTION match_documents(VECTOR(1536), FLOAT, INT) TO service_role;
GRANT EXECUTE ON FUNCTION match_documents(VECTOR(1536), FLOAT, INT) TO authenticated;
GRANT EXECUTE ON FUNCTION match_documents(VECTOR(1536), FLOAT, INT) TO anon;