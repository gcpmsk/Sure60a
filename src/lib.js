import { createClient } from '@supabase/supabase-js';
export const configured = Boolean(import.meta.env.VITE_SUPABASE_URL && import.meta.env.VITE_SUPABASE_ANON_KEY);
export const supabase = configured ? createClient(import.meta.env.VITE_SUPABASE_URL, import.meta.env.VITE_SUPABASE_ANON_KEY) : null;
export async function unwrap(promise) { const { data, error } = await promise; if (error) throw error; return data; }
export const defaults = { brand: 'Sure60', tagline: 'Your ambition. Our mission.', address: 'Karnal Campus, Karnal, Haryana', phone: '', email: '', announcement: 'A new chapter of your success starts here. Explore our learning programmes.', logo_url: '', instagram: '', youtube: '', facebook: '', telegram: '', whatsapp: '', map_url: '' };
export const defaultSlides = [
 {id:'s1',eyebrow:'LEARN WITH PURPOSE. ACHIEVE WITH CONFIDENCE.',title:'Big dreams.\nThe right direction.',description:'Expert-led classes, focused practice and a community that believes in you. Take your next big step with Sure60.',button_text:'Explore programmes',target:'batches',image_url:''},
 {id:'s2',eyebrow:'PRACTICE TODAY. PERFORM TOMORROW.',title:'Every question.\nOne step closer.',description:'Build confidence with timed practice tests, instant results and an all-student leaderboard. Make every attempt count.',button_text:'Explore test series',target:'tests',image_url:''},
 {id:'s3',eyebrow:'YOUR CLASSROOM, WHEREVER YOU ARE.',title:'Your pace.\nYour possibility.',description:'Revisit your favourite lessons, find subject-wise study notes and keep your preparation moving forward.',button_text:'Join the community',target:'register',image_url:''}
];
export const demoBatches = [
 {id:'b1',name:'NEET Achievers',category:'NEET',description:'A focused path to your medical dream. Learn concepts deeply and practise with purpose.',subjects:'Physics · Chemistry · Biology',duration:'Class 11 & 12',accent:'green'},
 {id:'b2',name:'JEE Trailblazers',category:'JEE',description:'Build strong fundamentals. Develop the problem-solving confidence to go further.',subjects:'Physics · Chemistry · Mathematics',duration:'Class 11 & 12',accent:'purple'},
 {id:'b3',name:'Foundation Plus',category:'Foundation',description:'Big achievements begin with strong foundations. Get a head start on your goals.',subjects:'Science · Mathematics · Aptitude',duration:'Class 9 & 10',accent:'orange'}
];
export const demoTests = [
 {id:'t1',title:'The Concept Challenger',subject:'Science',description:'A quick mix of science and mathematics to put your fundamentals to the test.',duration_minutes:5,marks_correct:4,marks_wrong:1,published:true},
 {id:'t2',title:'Maths Mind Sprint',subject:'Mathematics',description:'Sharpen your reasoning. A focused practice session for a confident start.',duration_minutes:5,marks_correct:4,marks_wrong:1,published:true}
];
export const demoQuestions = [
 {id:'q1',question:'What is the SI unit of force?',options:['Joule','Newton','Watt','Pascal'],correct:1},
 {id:'q2',question:'Which part of a cell is called its powerhouse?',options:['Nucleus','Ribosome','Mitochondrion','Cell wall'],correct:2},
 {id:'q3',question:'If 3x + 7 = 22, what is the value of x?',options:['3','4','5','6'],correct:2},
 {id:'q4',question:'What is the chemical symbol for sodium?',options:['S','So','Na','N'],correct:2},
 {id:'q5',question:'The angles of a triangle add up to how many degrees?',options:['90°','180°','270°','360°'],correct:1}
];
export const demoMathQuestions = [
 {id:'m1',question:'What is 15% of 200?',options:['15','20','30','45'],correct:2},
 {id:'m2',question:'What is the square root of 144?',options:['10','11','12','14'],correct:2},
 {id:'m3',question:'A square has side length 8 cm. What is its area?',options:['16 cm²','32 cm²','64 cm²','80 cm²'],correct:2},
 {id:'m4',question:'What is the next prime number after 7?',options:['8','9','10','11'],correct:3},
 {id:'m5',question:'What is the value of 2³ + 3²?',options:['13','17','18','25'],correct:1}
];
export function studentEmail(username) { return `${username.trim().toLowerCase()}@students.sure60.app`; }
export function safeUrl(value) { try { const u=new URL(value); return u.protocol==='https:' ? u.href : ''; } catch { return ''; } }
export function youtubeId(value) {
 try { const u=new URL(value); const h=u.hostname.toLowerCase().replace(/^www\./,''); let id='';
 if(h==='youtu.be') id=u.pathname.slice(1); else if(['youtube.com','m.youtube.com','youtube-nocookie.com'].includes(h)) id=u.searchParams.get('v') || u.pathname.match(/^\/(?:embed|shorts|live)\/([^/]+)/)?.[1] || '';
 return /^[a-zA-Z0-9_-]{11}$/.test(id)?id:'';
 }catch{return '';}
}
export function parseQuestions(text) {
 const source=text.replace(/\r/g,'').replace(/\\n/g,'\n');
 const blocks=[...source.matchAll(/(?:^|\n)\s*(\d+)\s*[.)]\s+([\s\S]*?)(?=(?:\n\s*\d+\s*[.)]\s+)|$)/g)];
 return blocks.map(([,number,block])=>{
  const parts=block.split(/(?:^|\n|\s{2,})([A-Da-d])[.)]\s+/);
  const options=['','','',''];
  for(let i=1;i<parts.length;i+=2) options[parts[i].toUpperCase().charCodeAt(0)-65]=parts[i+1]?.trim()||'';
  return {number:Number(number),question:parts[0].trim(),options,correct:-1};
 });
}
export function parseAnswers(text) {
 const map={}; for(const m of text.matchAll(/(?:^|[\s,;])(?:Q\s*)?(\d+)\s*[.):=\-]?\s*([A-D])(?=$|[\s,;])/gi)) map[Number(m[1])]=m[2].toUpperCase().charCodeAt(0)-65;
 return map;
}
export function validateQuestions(questions) {
 if(!Array.isArray(questions)||questions.length<1||questions.length>200) return 'Add between 1 and 200 questions.';
 for(let i=0;i<questions.length;i++){const q=questions[i];if(!q.question?.trim()||q.options?.length!==4||q.options.some(v=>typeof v!=='string'||!v.trim())||!Number.isInteger(q.correct)||q.correct<0||q.correct>3)return `Question ${i+1}: add the question, all four options and a correct answer.`;}
 return '';
}
export function grade(questions, answers, positive=4, negative=1) {
 let right_count=0,wrong_count=0,skipped_count=0;
 for(const q of questions){if(answers[q.id]===undefined)skipped_count++;else if(answers[q.id]===q.correct)right_count++;else wrong_count++;}
 return {right_count,wrong_count,skipped_count,score:right_count*positive-wrong_count*negative};
}
export async function readPDF(file) {
 if(!file||file.size>10*1024*1024) throw new Error('Choose a PDF smaller than 10 MB.');
 const pdfjs=await import('pdfjs-dist');
 pdfjs.GlobalWorkerOptions.workerSrc=new URL('pdfjs-dist/build/pdf.worker.min.mjs',import.meta.url).href;
 const doc=await pdfjs.getDocument({data:await file.arrayBuffer()}).promise; let text='';
 if(doc.numPages>100){await doc.destroy();throw new Error('Use a PDF with 100 pages or fewer.');}
 try{for(let p=1;p<=doc.numPages;p++){const page=await doc.getPage(p);const content=await page.getTextContent();let y=null;for(const item of content.items){if(!('str' in item))continue;if(y!==null&&Math.abs(y-item.transform[5])>3)text+='\n';text+=item.str+(item.hasEOL?'\n':'  ');y=item.transform[5];}text+='\n';}}finally{await doc.destroy();}
 if(text.trim().length<10)throw new Error('This PDF appears scanned/image-only. OCR it first, or enter the questions manually.');
 return text;
}
