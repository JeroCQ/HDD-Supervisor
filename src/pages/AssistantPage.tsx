/**
 * Field question interface. It sends a project/language-scoped question to ask-supervisor
 * and renders Gemini's structured answer plus short-lived source links. It never reads
 * kb_chunks or private Storage directly, preserving the secure final stage of RAG.
 */
import { useState } from "react";
import { supabase } from "../lib/supabase";
type Source={document_id:string;title:string;section:string|null;page_start:number;page_end:number;authority_rank:number;jurisdiction_scope:string;source_token:string};
type Answer={answer:string;what_to_say:string|null;authority_status:string;confidence:string;warnings:string[];sources:Source[]};
const quick=["Who gave us permission?","Get off my lawn","What if we hit a sprinkler?","Why are we potholing?","Can we bore here?","What do the locate markings mean?"];

/** Manages question submission. Inputs are validated server-side; invocation errors remain visible to the operator. */
export function AssistantPage(){const [query,setQuery]=useState("");const [language,setLanguage]=useState<"en"|"es">("en");const [answer,setAnswer]=useState<Answer|null>(null);const [error,setError]=useState("");const [busy,setBusy]=useState(false);
  /** Calls the authenticated answer function and records its typed response or safe error. */
  async function ask(text=query){if(!text.trim())return;setBusy(true);setError("");const {data,error}=await supabase.functions.invoke("ask-supervisor",{body:{query:text,project_code:"EP-22349",language}});setBusy(false);if(error)setError(error.message);else setAnswer(data);}
  /** Exchanges an opaque citation token for a 60-second signed URL; arbitrary paths never enter the browser request. */
  async function viewSource(source_token:string){const {data,error}=await supabase.functions.invoke("kb-admin",{body:{action:"signed_source",source_token}});if(error)setError(error.message);else window.open(data.url,"_blank","noopener,noreferrer");}
  return <><section className="panel"><h1>Field Assistant</h1><div className="controls"><select aria-label="Project"><option>EP-22349 - Saratoga Springs</option></select><select value={language} onChange={e=>setLanguage(e.target.value as "en"|"es")}><option value="en">English</option><option value="es">Español</option></select></div><textarea value={query} onChange={e=>setQuery(e.target.value)} placeholder="Ask a field question…"/><button onClick={()=>ask()} disabled={busy}>{busy?"Checking sources…":"Ask Supervisor"}</button><div className="quick">{quick.map(q=><button className="secondary" key={q} onClick={()=>{setQuery(q);void ask(q)}}>{q}</button>)}</div>{error&&<p className="warning">{error}</p>}</section>{answer&&<section className="answer"><h3>FIELD ANSWER</h3><p>{answer.answer}</p>{answer.what_to_say&&<><h3>WHAT TO SAY</h3><p>{answer.what_to_say}</p></>}<h3>WHY / AUTHORITY</h3><span className="badge">{answer.authority_status}</span><span className="badge">{answer.confidence}</span>{answer.warnings.map(w=><p className="warning" key={w}>{w}</p>)}<h3>SOURCES</h3>{answer.sources.map(s=><article className="source" key={s.source_token}><strong>{s.document_id} · {s.title}</strong><p>{s.section||"Unsectioned"} · page {s.page_start}{s.page_end!==s.page_start?`–${s.page_end}`:""}</p><span className="badge">Authority {s.authority_rank}</span><span className="badge">{s.jurisdiction_scope}</span><button onClick={()=>viewSource(s.source_token)}>View Source</button></article>)}</section>}</>}
