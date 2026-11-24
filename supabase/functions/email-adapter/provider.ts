import { bounded } from '../files/validation.ts'

const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i
const mailbox=/^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9-]+(?:\.[a-z0-9-]+)+$/
export const approvedRecipient=/^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@student\.ateneo\.edu$/
export type MailOutcome={outcome:'accepted';providerId:string}|{outcome:'retry';delay:number}|
  {outcome:'quota'|'failed'|'uncertain'}
export type MailHealth='pending'|'delivered'|'bounced'|'failed'
type Mail={subject:string;text:string}
export interface MailProvider {
  binding:{sender:string;domainId:string}
  verify():Promise<boolean>
  send(recipient:string,job:string,message:Mail):Promise<MailOutcome>
  status(delivery:string):Promise<MailHealth>
}

export function workspaceDigest(origin:string):Mail {
  const url=new URL(origin)
  if(url.protocol!=='https:'||url.origin!==origin||url.port||!/^[a-z0-9-]+(?:\.[a-z0-9-]+)+$/.test(url.hostname))
    throw Error('Invalid email workspace origin')
  return {subject:'Workspace updates',text:'You have workspace updates. Sign in to open your notifications.\n'+origin+'/notifications'}
}

export function approvedMail(config:{sender:string;domainId:string;sendKey:string;readKey:string},fetcher:typeof fetch=fetch):MailProvider {
  if(!mailbox.test(config.sender)||config.sender.length>254||!uuid.test(config.domainId)||
    ![config.sendKey,config.readKey].every(key=>/^re_[A-Za-z0-9_-]{8,128}$/.test(key)))throw Error('Invalid email configuration')
  const root='https://api.resend.com'
  async function request(path:string,key:string,options:RequestInit={}) {
    const response=await fetcher(root+path,{
      ...options,headers:{Authorization:'Bearer '+key,...options.headers},redirect:'error',signal:AbortSignal.timeout(5000),
    })
    const result=JSON.parse(new TextDecoder().decode(await bounded(response.body,32768)))
    return {response,result}
  }
  return {
    binding:{sender:config.sender,domainId:config.domainId},
    async verify() {
      try {
        const {response,result}=await request('/domains/'+config.domainId,config.readKey)
        return response.ok&&result?.id===config.domainId&&result?.name===config.sender.split('@')[1]&&result?.status==='verified'
      } catch {return false}
    },
    async send(recipient,job,message) {
      if(!approvedRecipient.test(recipient)||recipient.length>254||!uuid.test(job))return {outcome:'failed'}
      try {
        const {response,result}=await request('/emails',config.sendKey,{
          method:'POST',headers:{'Content-Type':'application/json','Idempotency-Key':'tedx-digest-'+job},
          body:JSON.stringify({from:config.sender,to:[recipient],subject:message.subject,text:message.text}),
        })
        if(response.ok)return uuid.test(result?.id??'')?{outcome:'accepted',providerId:result.id}:{outcome:'uncertain'}
        if(response.status===429) {
          if(['daily_quota_exceeded','monthly_quota_exceeded'].includes(result?.name))return {outcome:'quota'}
          const delay=Number(response.headers.get('Retry-After')??'60')
          if(result?.name==='rate_limit_exceeded'&&Number.isInteger(delay)&&delay>=1&&delay<=3600)return {outcome:'retry',delay}
          return {outcome:'failed'}
        }
        if([400,401,403,422].includes(response.status))return {outcome:'failed'}
        return {outcome:'uncertain'}
      } catch {return {outcome:'uncertain'}}
    },
    async status(delivery) {
      if(!uuid.test(delivery))return 'pending'
      try {
        const {response,result}=await request('/emails/'+delivery,config.readKey)
        if(!response.ok||result?.id!==delivery)return 'pending'
        if(result.last_event==='delivered')return 'delivered'
        if(['bounced','complained','suppressed'].includes(result.last_event))return 'bounced'
        return result.last_event==='failed'?'failed':'pending'
      } catch {return 'pending'}
    },
  }
}
