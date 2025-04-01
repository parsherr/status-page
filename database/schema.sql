-- Create services table
CREATE TABLE services (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) NOT NULL,
  url VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create status_checks table
CREATE TABLE status_checks (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  service_id UUID REFERENCES services(id) ON DELETE CASCADE,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  status_code INTEGER,
  response_time INTEGER, -- in milliseconds
  is_operational BOOLEAN NOT NULL,
  error TEXT
);

-- Create index for status_checks
CREATE INDEX idx_status_checks_service_timestamp ON status_checks (service_id, timestamp);

-- Create daily_summaries table
CREATE TABLE daily_summaries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  service_id UUID REFERENCES services(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  uptime_percentage NUMERIC(5, 2) NOT NULL, -- 0.00 to 100.00
  total_checks INTEGER NOT NULL,
  failed_checks INTEGER NOT NULL,
  outage_periods JSONB, -- Array of outage periods: [{"start": "12:30:00", "end": "13:45:00"}, ...]
  avg_response_time INTEGER, -- in milliseconds
  status VARCHAR(10) NOT NULL, -- GREEN, YELLOW, RED
  
  -- Composite unique constraint
  UNIQUE (service_id, date)
);

-- Create index for daily_summaries
CREATE INDEX idx_daily_summaries_service_date ON daily_summaries (service_id, date);

-- Create a function to clean up old data
CREATE OR REPLACE FUNCTION cleanup_old_data(retention_days INTEGER)
RETURNS void AS $$
DECLARE
  cutoff_date DATE;
BEGIN
  cutoff_date := CURRENT_DATE - retention_days;
  
  -- Delete old status checks
  DELETE FROM status_checks
  WHERE timestamp < cutoff_date;
  
  -- Delete old daily summaries
  DELETE FROM daily_summaries
  WHERE date < cutoff_date;
END;
$$ LANGUAGE plpgsql;

-- Create a scheduled job to run cleanup every day at 1 AM
-- Note: This requires pg_cron extension to be enabled in Supabase
-- If pg_cron is not available, you can handle this in your application code
/*
SELECT cron.schedule(
  'cleanup-old-data',
  '0 1 * * *',
  $$SELECT cleanup_old_data(45)$$
);
*/

-- Create RLS policies for security
-- Enable Row Level Security
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_summaries ENABLE ROW LEVEL SECURITY;

-- Create policies for authenticated users only
CREATE POLICY "Allow full access for authenticated users" ON services
  FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow full access for authenticated users" ON status_checks
  FOR ALL USING (auth.role() = 'authenticated');

CREATE POLICY "Allow full access for authenticated users" ON daily_summaries
  FOR ALL USING (auth.role() = 'authenticated');

INSERT INTO services (name, url, description)
VALUES 
  ('SetScript Ana Sayfa', 'https://setscript.com', 'SetScript ana web sitesi'),
  ('SetScript API', 'https://api.setscript.com', 'SetScript API servisi'),
  ('SetScript Docs', 'https://docs.setscript.com', 'SetScript geliştirici portalı'),
  ('SetScript AI', 'https://ai.setscript.com', 'SetScript yapay zeka servisi');

-- Note: You would typically not insert sample status_checks or daily_summaries
-- as these would be generated by your monitoring service 