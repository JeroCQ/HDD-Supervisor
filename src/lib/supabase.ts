/**
 * Creates the browser Supabase client for auth and Edge Function invocation.
 * It uses only the project URL and publishable/anon key; Gemini and service-role
 * secrets remain inside Edge Functions. This is the UI boundary of the RAG pipeline.
 */
import { createClient } from "@supabase/supabase-js";

const url = import.meta.env.VITE_SUPABASE_URL;
const publishableKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY ?? import.meta.env.VITE_SUPABASE_ANON_KEY;
if (!url || !publishableKey) throw new Error("Supabase browser configuration is missing");

/** Authenticated singleton used by pages; automatic token persistence supplies Edge Function authorization. */
export const supabase = createClient(url, publishableKey);
