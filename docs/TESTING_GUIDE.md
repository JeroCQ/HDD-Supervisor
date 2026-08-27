# Browser/cloud testing guide

No terminal is required for operation. In Supabase Dashboard, apply the migration in SQL Editor, deploy the four function folders through the Dashboard editor/integration, set `GEMINI_API_KEY` in Edge Function Secrets, and create your Auth user's `profiles` row with `is_admin=true` in Table Editor. In Lovable Preview, sign in, then use Knowledge Base to sync/scan/index and Evaluations to run tests.

Test boundaries: a normal account must receive “Administrator role required” for admin actions; no account receives KB rows directly; source links should expire after 60 seconds; a 301-page PDF without ranges should become `NEEDS_REVIEW`; a retry should reuse hashes. Validate English and Spanish questions, deliberate Provo comparison, EP-22349 Provo exclusion, explicit UDOT inclusion, citations, and PARTIAL access authority.

PASS targets: ≥90% expected-document top-five retrieval; 100% municipality exclusion; 100% legal answers cited; zero unsupported VERIFIED decisions; Spanish retrieval against English sources.
