# HDD RAG architecture audit

## Repository before this change

The starting Git tree contained only a one-line README. There was no frontend source, Supabase client, project URL, package manifest, auth implementation, upload/parser/chunker, database migration/schema/RLS, Edge Function, AI SDK, embedding/vector search, chat/RAG, knowledge-base provider, or third-party vector store to inspect or preserve. No `GEMINI_API_KEY`, OpenAI integration, demo record, or obsolete production component existed in the repository. The prompt states that an external user-owned Supabase project and private `kb-source-documents` bucket exist, but their live Dashboard contents are not accessible from this repository.

## Reused and created

The required existing external Supabase project and bucket remain the single canonical backend. The browser client uses its URL plus publishable key; all privileged operations use hosted functions. New code adds a responsive assistant/admin shell, PDF.js parser adapter, canonical schema/RLS/RPC, ingestion/admin/answer/evaluation functions, and browser-only owner documentation.

Gemini remains the sole AI provider. `GEMINI_API_KEY` is referenced only in `supabase/functions/_shared/core.ts`; the package is Google's `@google/genai`; generation uses `gemini-2.5-flash`; embeddings use new `gemini-embedding-001` at 1,536 dimensions because no embedding implementation existed; structured JSON schema output is implemented in `ask-supervisor`. No OpenAI package/key/code was added despite duplicated later requirements mentioning OpenAI, because the leading non-negotiable requirement controls.

## External project connection audit

No Supabase URL/project ref or key existed in the starting repository, so a specific ref cannot truthfully be documented or confirmed from source. The frontend now connects through `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` (with legacy anon-key fallback). The URL/ref is not a secret, but operators must retain the values for their current user-owned project in Lovable. Service-role and Gemini secrets exist only in hosted function environment variables. Dashboard verification is the required confirmation that this configured URL is the stated external project; no second database or Lovable-managed backend is created.

## Replaced, obsolete, deletion plan

Nothing was replaced or deleted because nothing beyond README existed. There is no confirmed demo vector database or duplicate flow. If another branch/deployed Lovable project contains code absent from this checkout, merge/audit it before deleting anything. Only after browser evaluations pass should a maintainer remove a demonstrably unused deployed placeholder; preserve Auth users, Storage files, chat history, and unrelated features.
