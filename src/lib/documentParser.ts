/**
 * Browser PDF.js adapter implementing the DocumentParser contract. The authenticated admin UI
 * receives a short-lived private Storage URL, extracts text page-by-page without losing page
 * numbers, applies optional ranges, and sends only page text to ingest-document. Gemini secrets
 * never enter this parser; it is the extraction step between Storage and server-side chunking.
 */
import * as pdfjs from "pdfjs-dist";
export type ParsedPage={pageNumber:number;text:string;headings?:string[];metadata?:Record<string,unknown>};
export interface DocumentParser{parse(url:string,pageRanges?:string|null):Promise<{pages:ParsedPage[]}>}
/** Expands validated inclusive range notation into a page allow-list; blank means every page. */
export function parsePageRanges(value:string|null|undefined,total:number){if(!value)return new Set(Array.from({length:total},(_,i)=>i+1));const selected=new Set<number>();for(const part of value.split(",")){const [a,b=a]=part.trim().split("-").map(Number);if(!Number.isInteger(a)||!Number.isInteger(b)||a<1||b<a||b>total)throw new Error(`Invalid page range: ${part}`);for(let n=a;n<=b;n++)selected.add(n)}return selected}
/** Extracts PDF text in reading order per page. Encrypted/scanned PDFs fail visibly for admin review. */
export class PdfJsDocumentParser implements DocumentParser{async parse(url:string,pageRanges?:string|null){const task=pdfjs.getDocument({url,disableWorker:true} as never);const pdf=await task.promise;if(pdf.numPages>300&&!pageRanges)throw new Error("Documents over 300 pages require selected page ranges");const selected=parsePageRanges(pageRanges,pdf.numPages),pages:ParsedPage[]=[];for(const pageNumber of selected){const page=await pdf.getPage(pageNumber);const content=await page.getTextContent();const text=content.items.map(item=>("str" in item?item.str:"")).join(" ").replace(/\s+/g," ").trim();pages.push({pageNumber,text,metadata:{width:page.view[2],height:page.view[3]}})}return {pages}}}
