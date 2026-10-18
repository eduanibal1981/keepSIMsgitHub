CREATE TABLE public.test_cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  feature_group TEXT NOT NULL,
  test_name TEXT NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'passed', 'failed', 'needs_review')),
  ai_task_request TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_test_cases_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_test_cases_updated_at
BEFORE UPDATE ON public.test_cases
FOR EACH ROW EXECUTE FUNCTION update_test_cases_updated_at();

-- RLS
ALTER TABLE public.test_cases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow authenticated users to read test cases"
ON public.test_cases FOR SELECT TO authenticated
USING (true);

CREATE POLICY "Allow authenticated users to insert test cases"
ON public.test_cases FOR INSERT TO authenticated
WITH CHECK (true);

CREATE POLICY "Allow authenticated users to update test cases"
ON public.test_cases FOR UPDATE TO authenticated
USING (true);

CREATE POLICY "Allow authenticated users to delete test cases"
ON public.test_cases FOR DELETE TO authenticated
USING (true);
