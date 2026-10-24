// @vitest-environment node
import {describe,it,expect,vi} from 'vitest'
import {deflateSync} from 'node:zlib'
import {validateFile,workingUrl,MAX_FILE,FileFault} from '../../../supabase/functions/files/validation'
import {fileHandler,type FileBackend} from '../../../supabase/functions/files/handler'
const id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa8',assetId='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1'
function png(){function chunk(type:string,body:Buffer){const data=Buffer.concat([Buffer.from(type),body]);let c=0xffffffff;for(const b of data){c^=b;for(let i=0;i<8;i++)c=(c>>>1)^((c&1)?0xedb88320:0)}const length=Buffer.alloc(4),sum=Buffer.alloc(4);length.writeUInt32BE(body.length);sum.writeUInt32BE((c^0xffffffff)>>>0);return Buffer.concat([length,data,sum])}const head=Buffer.alloc(13);head.writeUInt32BE(1,0);head.writeUInt32BE(1,4);head[8]=8;head[9]=6;return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',head),chunk('IDAT',deflateSync(Buffer.from([0,0,0,0,255]))),chunk('IEND',Buffer.alloc(0))])}
describe('P12 file boundaries',()=>{
 it('P12_A2: validates PNG CRC/decompressed size and rejects MIME mismatch, executable/SVG/HTML/archive, trailing data, corrupt and oversize files',async()=>{
  expect((await validateFile('synthetic.png','image/png',png())).sha256).toMatch(/^[0-9a-f]{64}$/)
  for(const [name,mime,data]of [['x.svg','image/svg+xml',Buffer.from('<svg/>')],['x.html','text/html',Buffer.from('<script/>')],['x.zip','application/zip',Buffer.from('PK')],['x.exe','application/pdf',Buffer.from('MZ')],['x.png','application/pdf',png()],['x.png','image/png',Buffer.concat([png(),Buffer.from('<script/>')])],['x.png','image/png',new Uint8Array(MAX_FILE+1)],['x.jpg','image/jpeg',Buffer.from([255,216,255,217])]] as const)await expect(validateFile(name,mime,data)).rejects.toBeInstanceOf(FileFault)
  const damaged=png();damaged[30]^=1;await expect(validateFile('x.png','image/png',damaged)).rejects.toBeInstanceOf(FileFault)
 })
 it('P12_A2: conservative PDF checks reject active/obfuscated/encrypted/embedded content',async()=>{for(const token of ['/JavaScript','/J#61vaScript','/OpenAction','/EmbeddedFile','/Encrypt','/ObjStm','/Launch'])await expect(validateFile('x.pdf','application/pdf',Buffer.from('%PDF-1.4\nxref\n'+token+'\nstartxref\n1\n%%EOF'))).rejects.toBeInstanceOf(FileFault)})
 it('accepts only exact working provider hosts and canonical file paths, stripping query/fragment',()=>{expect(workingUrl('https://docs.google.com/document/d/Fictional/edit?sharing=1#x')).toBe('https://docs.google.com/document/d/Fictional/edit');for(const url of ['javascript:alert(1)','http://docs.google.com/document/d/x/edit','https://docs.google.com.evil.test/document/d/x/edit','https://user@docs.google.com/document/d/x/edit','https://drive.google.com/drive/folders/x','https://www.canva.com.evil.test/design/x/view'])expect(()=>workingUrl(url)).toThrow()})
 it('does not let a client reach storage before auth, and reauthorizes after fetching bytes',async()=>{
  const bytes=png(),hash=(await validateFile('x.png','image/png',bytes)).sha256
  const backend:FileBackend={authenticate:vi.fn().mockResolvedValue(undefined),rpc:vi.fn().mockResolvedValue({kind:'upload',path:'random.png',mime:'image/png',size:bytes.length,sha256:hash}),get:vi.fn().mockResolvedValue(bytes),put:vi.fn(),seal:vi.fn()}
  const h=fileHandler(backend,'https://fictional.test'),body=JSON.stringify({action:'download',workId:id,assetId,key:crypto.randomUUID()})
  expect((await h(new Request('https://fictional.test/files',{method:'POST',body}))).status).toBe(403);expect(backend.get).not.toHaveBeenCalled()
  vi.mocked(backend.rpc).mockResolvedValueOnce({kind:'upload',path:'random.png',mime:'image/png',size:bytes.length,sha256:hash}).mockRejectedValueOnce(new FileFault('42501'))
  const r=await h(new Request('https://fictional.test/files',{method:'POST',headers:{authorization:'Bearer synthetic','content-type':'application/json'},body}));expect(r.status).toBe(403);expect(r.headers.get('cache-control')).toContain('no-store');expect(backend.rpc).toHaveBeenCalledTimes(2)
 })
})
