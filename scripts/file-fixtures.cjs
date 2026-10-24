const {deflateSync}=require('node:zlib')
function crc(b){let n=0xffffffff;for(const v of b){n^=v;for(let k=0;k<8;k++)n=(n>>>1)^((n&1)?0xedb88320:0)}return(n^0xffffffff)>>>0}
function chunk(type,body){const data=Buffer.concat([Buffer.from(type),body]),size=Buffer.alloc(4),sum=Buffer.alloc(4);size.writeUInt32BE(body.length);sum.writeUInt32BE(crc(data));return Buffer.concat([size,data,sum])}
function png(){const header=Buffer.alloc(13);header.writeUInt32BE(1,0);header.writeUInt32BE(1,4);header[8]=8;header[9]=6;return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',header),chunk('IDAT',deflateSync(Buffer.from([0,184,35,32,255]))),chunk('IEND',Buffer.alloc(0))])}
function pdf(){let text='%PDF-1.4\n';const offsets=[0];for(const object of ['<< /Type /Catalog /Pages 2 0 R >>','<< /Type /Pages /Kids [] /Count 0 >>']){offsets.push(text.length);text+=`${offsets.length-1} 0 obj\n${object}\nendobj\n`}const xref=text.length;text+='xref\n0 3\n0000000000 65535 f \n'+offsets.slice(1).map(n=>String(n).padStart(10,'0')+' 00000 n \n').join('')+'trailer\n<< /Size 3 /Root 1 0 R >>\nstartxref\n'+xref+'\n%%EOF\n';return Buffer.from(text)}
module.exports={png,pdf}
