import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { createHealthHandler } from "./handler.ts";

serve(createHealthHandler(createClient, (key) => Deno.env.get(key)));
