export type TelegramRpc=(name:string,fields:Record<string,unknown>)=>Promise<unknown>

export function telegramRpc(url:string,service:string):TelegramRpc {
  return async(name,fields)=>{
    const response=await fetch(url.replace(/\/$/,'')+'/rest/v1/rpc/'+name,{
      method:'POST',headers:{apikey:service,authorization:'Bearer '+service,'content-type':'application/json'},
      body:JSON.stringify(fields),redirect:'error',signal:AbortSignal.timeout(5000),
    })
    if(!response.ok)throw Error('Telegram service unavailable')
    return response.json()
  }
}

export function matchesTelegramSecret(header:string|null,secret:string) {
  const value=header??''
  let difference=value.length^secret.length
  for(let index=0;index<secret.length;index++)difference|=(value.charCodeAt(index)||0)^secret.charCodeAt(index)
  return difference===0
}
