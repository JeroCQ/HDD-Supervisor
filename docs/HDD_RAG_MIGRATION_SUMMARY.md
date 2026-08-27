# HDD RAG migration summary

**Retained:** the named user-owned external Supabase backend, private `kb-source-documents` bucket, Gemini-only provider requirement, and project data ownership/visibility.

**Created:** canonical project/document/chunk/job/evaluation tables; pgvector and language-neutral FTS indexes; RLS; server-only hybrid RPC; EP-22349 and ten eval seeds; browser field/admin/eval routes; PDF.js page extraction; structure-aware chunking; Gemini embeddings/generation; source signing; and owner guides.

**Changed:** the initial README now points to operating documentation. No prior application source existed to refactor.

**Removed:** nothing. There were no confirmed demo records, fake responses, alternate vector stores, upload flows, or placeholder functions in this Git checkout.

**Browser configuration remaining:** apply the migration and deploy functions in the external Supabase Dashboard, add only `GEMINI_API_KEY` to hosted Edge Function Secrets, create the admin profile row, retain that project's URL/publishable key in Lovable, then sync, ingest, and run all evaluations. These are browser actions; users need no terminal.
