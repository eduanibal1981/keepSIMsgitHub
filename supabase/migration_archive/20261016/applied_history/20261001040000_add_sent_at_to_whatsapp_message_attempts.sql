-- Migration: 20261001040000_add_sent_at_to_whatsapp_message_attempts.sql
-- Description: Adds sent_at column to whatsapp_message_attempts so Baileys and Meta provider workers
-- can record the transmission timestamp without schema mismatch errors.

ALTER TABLE public.whatsapp_message_attempts 
  ADD COLUMN IF NOT EXISTS sent_at TIMESTAMPTZ;
