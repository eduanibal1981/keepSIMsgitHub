-- Migration: 20260827000000_realtime_sim_lines_and_executions.sql
-- Enables REPLICA IDENTITY FULL on sim_lines and topup_executions to allow
-- Supabase Realtime to broadcast update payloads with complete row information
-- and enables realtime publication on sim_lines.

ALTER TABLE public.sim_lines REPLICA IDENTITY FULL;
ALTER TABLE public.topup_executions REPLICA IDENTITY FULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'sim_lines'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.sim_lines;
  END IF;
END $$;
