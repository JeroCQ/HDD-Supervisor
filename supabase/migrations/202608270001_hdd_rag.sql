-- HDD RAG canonical schema. This migration stores project-aware legal evidence in the user's
-- external Supabase Postgres, keeps private Storage references, and exposes server-only retrieval.

-- pgvector stores Gemini's 1,536-value semantic representation beside searchable source text.
create extension if not exists vector with schema extensions;
-- pgcrypto generates opaque identifiers without trusting browser input.
create extension if not exists pgcrypto with schema extensions;

-- The authorization enum prevents accidental free-form project authority states.
create type public.project_authorization_status as enum ('PARTIAL','VERIFIED','EXPIRED','UNKNOWN');
-- The ingestion enum makes every retryable document lifecycle transition visible to admins.
create type public.kb_ingestion_status as enum ('NOT_INGESTED','QUEUED','PROCESSING','READY','PARTIAL','FAILED','NEEDS_REVIEW');

-- Projects bind questions to jurisdiction and prevent unrelated municipal material becoming authority.
create table public.projects (
 id uuid primary key default extensions.gen_random_uuid(), project_code text unique not null,
 city text, state text not null default 'UT', utility_owner text, contractor text,
 authorization_status public.project_authorization_status not null default 'UNKNOWN', jurisdiction_scope text,
 active boolean not null default true, metadata jsonb not null default '{}',
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
comment on table public.projects is 'Field projects and their controlling jurisdiction/authority state.';

-- KB documents are the durable manifest and indexing state for each private Storage object.
create table public.kb_documents (
 id uuid primary key default extensions.gen_random_uuid(), document_id text unique not null, filename text not null, title text not null,
 storage_bucket text not null default 'kb-source-documents', storage_path text unique not null, jurisdiction text, jurisdiction_scope text not null default 'GENERAL', issuer text,
 source_type text, authority_level text, authority_rank integer not null default 20 check(authority_rank between 0 and 100), project_specific boolean not null default false,
 project_code text references public.projects(project_code), status text, priority text, effective_date date, retrieved_at timestamptz, source_url text,
 rag_ingest boolean not null default true, is_current boolean not null default true, superseded_by uuid references public.kb_documents(id), tags text[] not null default '{}',
 page_ranges_to_ingest text, content_hash text, parser_name text, parser_version text, embedding_model text, embedding_dimensions integer,
 ingestion_status public.kb_ingestion_status not null default 'NOT_INGESTED', ingestion_error text, chunk_count integer not null default 0,
 metadata jsonb not null default '{}', created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
comment on table public.kb_documents is 'One row per source PDF; preserves identity, authority, parsing, and replacement history.';

-- Chunks preserve page and legal structure while holding Gemini vectors for hybrid evidence retrieval.
create table public.kb_chunks (
 id bigint generated always as identity primary key, document_id uuid not null references public.kb_documents(id) on delete cascade,
 chunk_index integer not null, section_title text, section_path text, legal_citation text, page_start integer not null, page_end integer not null,
 content text not null, normalized_content text not null, token_count integer not null, embedding extensions.vector(1536),
 jurisdiction_scope text not null, project_code text, authority_rank integer not null, intent_tags text[] not null default '{}', objection_types text[] not null default '{}', audience text[] not null default '{}',
 legal_authority boolean not null default false, content_hash text not null, metadata jsonb not null default '{}', created_at timestamptz not null default now(),
 unique(document_id,chunk_index), check(page_start > 0 and page_end >= page_start)
);
comment on table public.kb_chunks is 'Page-aware, structure-aware source passages and 1,536-dimensional Gemini embeddings.';

-- Ingestion jobs provide auditable progress, failure, and retry state without exposing secrets.
create table public.kb_ingestion_jobs (
 id uuid primary key default extensions.gen_random_uuid(), document_id uuid not null references public.kb_documents(id), storage_path text not null,
 status public.kb_ingestion_status not null default 'QUEUED', requested_by uuid references auth.users(id), page_ranges text,
 pages_processed integer not null default 0, pages_total integer, chunks_created integer not null default 0,
 started_at timestamptz, completed_at timestamptz, error text, logs jsonb not null default '[]', created_at timestamptz not null default now()
);
comment on table public.kb_ingestion_jobs is 'Browser-requested cloud ingestion attempts and non-secret operational logs.';

-- Evaluation cases define browser-runnable expectations for retrieval and safe field behavior.
create table public.rag_eval_cases (id uuid primary key default extensions.gen_random_uuid(), name text unique not null, active boolean not null default true,
 project_code text, query text not null, language text not null default 'en', expected_document_ids text[] not null default '{}', forbidden_document_ids text[] not null default '{}',
 expected_concepts text[] not null default '{}', expected_authority_status text, notes text, created_at timestamptz not null default now());
comment on table public.rag_eval_cases is 'Repeatable bilingual retrieval, jurisdiction, citation, and behavior acceptance cases.';

-- Evaluation runs retain exact outcomes so regressions are visible in the admin UI.
create table public.rag_eval_runs (id uuid primary key default extensions.gen_random_uuid(), eval_case_id uuid not null references public.rag_eval_cases(id), query text not null,
 returned_document_ids text[] not null default '{}', answer text, retrieval_pass boolean not null, jurisdiction_pass boolean not null, citation_pass boolean not null,
 behavior_pass boolean not null, overall_pass boolean not null, details jsonb not null default '{}', created_at timestamptz not null default now());
comment on table public.rag_eval_runs is 'Persisted hosted evaluation outcomes for visible PASS/FAIL reporting.';

-- Profiles reuse Supabase Auth identities and provide a server-checked admin flag, never a client assertion.
create table public.profiles (id uuid primary key references auth.users(id) on delete cascade, is_admin boolean not null default false, created_at timestamptz not null default now());
comment on table public.profiles is 'Authorization profile; only trusted Dashboard operations grant administrator status.';

-- HNSW accelerates cosine nearest-neighbor lookup over Gemini vectors.
create index kb_chunks_embedding_hnsw on public.kb_chunks using hnsw (embedding extensions.vector_cosine_ops);
-- Simple-config FTS remains language-neutral enough for English evidence queried in English or Spanish.
create index kb_chunks_fts_gin on public.kb_chunks using gin (to_tsvector('simple', normalized_content));
-- Array GIN indexes accelerate intent metadata filtering before answer generation.
create index kb_chunks_intent_tags_gin on public.kb_chunks using gin(intent_tags);
create index kb_chunks_objection_types_gin on public.kb_chunks using gin(objection_types);
-- Scalar indexes bound candidate sets by project and jurisdiction before ranking authority.
create index kb_chunks_project_idx on public.kb_chunks(project_code);
create index kb_chunks_scope_idx on public.kb_chunks(jurisdiction_scope);
create index kb_documents_status_idx on public.kb_documents(ingestion_status,is_current,rag_ingest);

-- hybrid_search_kb fuses semantic and keyword ranks only after applying project/jurisdiction constraints.
create function public.hybrid_search_kb(query_text text, query_embedding extensions.vector(1536), project_code text default null,
 jurisdiction_scope text default null, include_udot boolean default false, match_count integer default 8, semantic_weight real default 1, keyword_weight real default 1)
returns table(chunk_id bigint, document_id text, filename text, title text, section_title text, legal_citation text, page_start integer, page_end integer,
 content text, jurisdiction_scope text, project_code text, authority_rank integer, semantic_score real, keyword_score real, final_score real)
language sql stable security definer set search_path=public,extensions as $$
with eligible as (
 select c.*,d.document_id as external_id,d.filename,d.title
 from kb_chunks c join kb_documents d on d.id=c.document_id
 where d.rag_ingest and d.is_current and d.ingestion_status='READY'
 and (hybrid_search_kb.project_code is null or c.project_code is null or c.project_code=hybrid_search_kb.project_code)
 and (hybrid_search_kb.jurisdiction_scope is null or c.jurisdiction_scope in (hybrid_search_kb.jurisdiction_scope,'UTAH_STATEWIDE','FEDERAL','GENERAL',hybrid_search_kb.project_code)
      or (hybrid_search_kb.jurisdiction_scope='PROVO' and c.jurisdiction_scope='PROVO'))
 and (include_udot or c.jurisdiction_scope <> 'UDOT_ROW_ONLY')
 and not (hybrid_search_kb.project_code='EP-22349' and c.jurisdiction_scope in ('PROVO','WEST_JORDAN'))
), sem as (select id,row_number() over(order by embedding <=> query_embedding) rank,(1-(embedding <=> query_embedding))::real score from eligible where embedding is not null limit greatest(match_count*4,20)),
key as (select id,row_number() over(order by ts_rank_cd(to_tsvector('simple',normalized_content),websearch_to_tsquery('simple',query_text)) desc) rank,
 ts_rank_cd(to_tsvector('simple',normalized_content),websearch_to_tsquery('simple',query_text))::real score from eligible where to_tsvector('simple',normalized_content) @@ websearch_to_tsquery('simple',query_text) limit greatest(match_count*4,20)),
fused as (select coalesce(sem.id,key.id) id,coalesce(sem.score,0) semantic_score,coalesce(key.score,0) keyword_score,
 (semantic_weight/coalesce(60+sem.rank,1)+keyword_weight/coalesce(60+key.rank,1))::real fusion from sem full join key using(id))
select e.id,e.external_id,e.filename,e.title,e.section_title,e.legal_citation,e.page_start,e.page_end,e.content,e.jurisdiction_scope,e.project_code,e.authority_rank,
 f.semantic_score,f.keyword_score,(f.fusion*(1+e.authority_rank::real/500))::real final_score from fused f join eligible e on e.id=f.id order by final_score desc limit match_count;
$$;
comment on function public.hybrid_search_kb is 'Server-only reciprocal-rank fusion of Gemini cosine similarity and simple full-text search with applicability filtering.';
revoke all on function public.hybrid_search_kb(text,extensions.vector,text,text,boolean,integer,real,real) from public,anon,authenticated;
grant execute on function public.hybrid_search_kb(text,extensions.vector,text,text,boolean,integer,real,real) to service_role;

-- RLS defaults every canonical table to no browser access; Edge Functions use authenticated checks plus service role.
alter table public.projects enable row level security; alter table public.kb_documents enable row level security; alter table public.kb_chunks enable row level security;
alter table public.kb_ingestion_jobs enable row level security; alter table public.rag_eval_cases enable row level security; alter table public.rag_eval_runs enable row level security; alter table public.profiles enable row level security;
-- Users may inspect only their own role flag; they cannot grant it or read another user's role.
create policy "users read own profile" on public.profiles for select to authenticated using(id=auth.uid());
comment on policy "users read own profile" on public.profiles is 'Lets users inspect their identity while preventing privilege discovery or escalation.';

-- The existing private bucket is reinforced as private; no direct object listing policy is introduced.
update storage.buckets set public=false where id='kb-source-documents';

-- EP-22349 establishes the default Saratoga context while explicitly retaining PARTIAL authority.
insert into public.projects(project_code,city,state,utility_owner,contractor,authorization_status,jurisdiction_scope)
values('EP-22349','Saratoga Springs','UT','CenturyLink / Lumen','Niels Fugal Sons','PARTIAL','SARATOGA_SPRINGS') on conflict(project_code) do nothing;

-- Ten acceptance cases exercise project authority, municipal exclusions, UDOT, Spanish, damage, and LEAPS behavior.
insert into public.rag_eval_cases(name,project_code,query,language,expected_document_ids,forbidden_document_ids,expected_concepts,expected_authority_status,notes) values
('Potholing','EP-22349','Do we have to pothole before directional boring?','en','{PRJ01}','{M02}','{yes,pothole}',null,'Provo and West Jordan cannot be primary authority.'),
('Permission','EP-22349','Who gave us permission to work here?','en','{PRJ01}','{M02}','{approved plans,easement}','PARTIAL','Generic law alone cannot verify site access.'),
('Tolerance zone',null,'Can we use powered boring equipment inside the tolerance zone?','en','{A02}','{}','{precise location,exception}',null,'Utah Code 54-8a-5.5.'),
('Facility damage',null,'What happens if we damage an underground facility?','en','{A02}','{}','{notify,damage}',null,'Utah Code 54-8a-7.'),
('Reject Provo authority','EP-22349','Can I rely on the Provo directional boring standard here?','en','{}','{M02}','{no,not applicable}',null,'Comparison mention must not become authority.'),
('Provo depth',null,'How deep is a directional bore in Provo?','en','{M02}','{}','{P-257,P-258}',null,'Explicit Provo query allows Provo.'),
('UDOT permit',null,'Can a contractor work on UDOT ROW before the encroachment permit is issued?','en','{A03}','{}','{no,permit}',null,'Explicit UDOT query enables UDOT_ROW_ONLY.'),
('Spanish tolerance',null,'¿Podemos usar una máquina para perforar dentro de la zona de tolerancia?','es','{A02}','{}','{ubicación precisa,excepción}',null,'Spanish answer cites English original.'),
('Spanish homeowner','EP-22349','El dueño de la casa dice que nos salgamos de su propiedad. ¿Qué le digo?','es','{PRJ01,C01}','{M02}','{calmado,planes aprobados}','PARTIAL','Do not overstate private-property access.'),
('LEAPS',null,'What is LEAPS?','en','{C01}','{}','{communication}','NOT_APPLICABLE','Communication material is never legal authority.')
on conflict(name) do nothing;
