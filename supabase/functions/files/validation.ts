export const MAX_FILE=5*1024*1024
export const MAX_MANIFEST=20*1024*1024
export class FileFault extends Error {code:string;tag:string;constructor(code='22023',tag='file_request_rejected'){super('File request rejected');this.code=code;this.tag=['command_idempotency_conflict','command_quota_limit','command_stale_version'].includes(tag)?tag:'file_request_rejected'}}
export async function bounded(body:ReadableStream<Uint8Array>|null,limit:number):Promise<Uint8Array>{
 if(!body)throw new FileFault();const chunks:Uint8Array[]=[];let size=0;const reader=body.getReader()
 try{for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>limit){await reader.cancel();throw new FileFault()}chunks.push(value)}}finally{reader.releaseLock()}
 const out=new Uint8Array(size);let offset=0;for(const c of chunks){out.set(c,offset);offset+=c.length}return out
}
export async function digest(bytes:Uint8Array):Promise<string>{return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',bytes as Uint8Array<ArrayBuffer>)),x=>x.toString(16).padStart(2,'0')).join('')}
function crc(bytes:Uint8Array){let n=0xffffffff;for(const b of bytes){n^=b;for(let i=0;i<8;i++)n=(n>>>1)^((n&1)?0xedb88320:0)}return(n^0xffffffff)>>>0}
async function png(b:Uint8Array){
 if(b.length<45||[137,80,78,71,13,10,26,10].some((v,i)=>b[i]!==v))throw new FileFault()
 const view=new DataView(b.buffer,b.byteOffset,b.byteLength);let offset=8,width=0,height=0,channels=0,end=false;const chunks:Uint8Array[]=[]
 while(offset+12<=b.length){const size=view.getUint32(offset),type=new TextDecoder().decode(b.slice(offset+4,offset+8));if(size>b.length-offset-12||view.getUint32(offset+8+size)!==crc(b.slice(offset+4,offset+8+size)))throw new FileFault()
 if(offset===8&&type!=='IHDR')throw new FileFault()
 if(type==='IHDR'){if(offset!==8||size!==13||b[offset+16]!==8||![0,2,6].includes(b[offset+17])||b[offset+18]!==0||b[offset+19]!==0||b[offset+20]!==0)throw new FileFault();width=view.getUint32(offset+8);height=view.getUint32(offset+12);channels=({0:1,2:3,6:4} as Record<number,number>)[b[offset+17]];if(!width||!height||width>4096||height>4096||width*height>4194304)throw new FileFault()}
 else if(type==='IDAT')chunks.push(b.slice(offset+8,offset+8+size))
 else if(type==='IEND'){if(size||offset+12!==b.length||!chunks.length)throw new FileFault();end=true}
 else if(!['sRGB','gAMA','cHRM','pHYs'].includes(type))throw new FileFault()
 offset+=size+12
 }if(!end||offset!==b.length)throw new FileFault()
 const packed=new Uint8Array(chunks.reduce((n,c)=>n+c.length,0));let pos=0;for(const c of chunks){packed.set(c,pos);pos+=c.length}
 try{const stride=width*channels+1,raw=await bounded(new Blob([packed]).stream().pipeThrough(new DecompressionStream('deflate')),stride*height);if(raw.length!==stride*height)throw new FileFault();for(let i=0;i<raw.length;i+=stride)if(raw[i]>4)throw new FileFault()}catch{throw new FileFault()}
}
function jpeg(b:Uint8Array){
 if(b[0]!==255||b[1]!==216)throw new FileFault();let p=2,frame=false,scan=false,end=false
 while(p<b.length){if(b[p++]!==255)throw new FileFault();while(b[p]===255)p++;const marker=b[p++];if(marker===217){end=p===b.length;break}if(marker===216||marker===0||marker>=208&&marker<=215||p+2>b.length)throw new FileFault();const size=(b[p]<<8)|b[p+1];if(size<2||p+size>b.length)throw new FileFault()
 if(marker===192||marker===194){const height=(b[p+3]<<8)|b[p+4],width=(b[p+5]<<8)|b[p+6];if(size<8||b[p+2]!==8||!height||!width||height>4096||width>4096||height*width>4194304)throw new FileFault();frame=true}
 p+=size;if(marker===218){if(!frame)throw new FileFault();scan=true;while(p<b.length){if(b[p]!==255){p++;continue}if(b[p+1]===0||b[p+1]>=208&&b[p+1]<=215){p+=2;continue}break}}
 }if(!frame||!scan||!end)throw new FileFault()
}
export async function validateFile(name:string,mime:string,bytes:Uint8Array){
 if(!name||name.length>160||/[\r\n/\\\0]/.test(name)||!bytes.length||bytes.length>MAX_FILE)throw new FileFault()
 const ext=name.split('.').at(-1)?.toLowerCase(),expected=ext==='pdf'?'application/pdf':ext==='png'?'image/png':['jpg','jpeg'].includes(ext??'')?'image/jpeg':null
 if(!expected||mime!==expected)throw new FileFault()
 if(mime==='image/png')await png(bytes)
 else if(mime==='image/jpeg')jpeg(bytes)
 else {const text=new TextDecoder('latin1').decode(bytes);const normalized=text.replace(/#([0-9a-f]{2})/gi,(_,hex)=>String.fromCharCode(parseInt(hex,16)));if(!/^%PDF-1\.[0-7][\r\n]/.test(text)||! /%%EOF\s*$/.test(text)||!text.includes('startxref')||!text.includes('xref')||/\/(JavaScript|JS|OpenAction|AA|Launch|EmbeddedFile|Filespec|RichMedia|XFA|AcroForm|Encrypt|ObjStm|URI)\b/i.test(normalized)||text.indexOf('%%EOF')!==text.lastIndexOf('%%EOF'))throw new FileFault()}
 return{mime,size:bytes.length,sha256:await digest(bytes)}
}
export function workingUrl(raw:string):string{
 let u:URL;try{u=new URL(raw)}catch{throw new FileFault()}
 if(u.protocol!=='https:'||u.username||u.password||u.port)throw new FileFault()
 const url=u.origin+u.pathname
 if(!/^https:\/\/(drive\.google\.com\/file\/d\/[A-Za-z0-9_-]+\/(view|edit)|docs\.google\.com\/(document|spreadsheets|presentation)\/d\/[A-Za-z0-9_-]+\/(edit|view)|www\.canva\.com\/design\/[A-Za-z0-9_-]+(\/[A-Za-z0-9_-]+)?\/(edit|view))$/.test(url))throw new FileFault()
 return url
}
