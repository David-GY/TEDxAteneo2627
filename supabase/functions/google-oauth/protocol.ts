const encoder = new TextEncoder()
const base64url = (bytes: Uint8Array) => btoa(String.fromCharCode(...bytes)).replaceAll('+','-').replaceAll('/','_').replace(/=+$/,'')
const decode = (value: string) => Uint8Array.from(atob(value.replaceAll('-','+').replaceAll('_','/')), character => character.charCodeAt(0))
const random = (size: number) => crypto.getRandomValues(new Uint8Array(size))

export const driveNonce = /^[A-Za-z0-9_-]{43}$/
export const driveFileId = /^[A-Za-z0-9_-]{1,180}$/
export const schoolAddress = /^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@student\.ateneo\.edu$/
export const isDriveUuid = (value: unknown): value is string => typeof value==='string' &&
  /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i.test(value)

export async function driveHash(value: string) {
  return Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',encoder.encode(value))), b=>b.toString(16).padStart(2,'0')).join('')
}

export async function makeDriveAttempt() {
  const state = base64url(random(32))
  const verifier = base64url(random(32))
  const challenge = base64url(new Uint8Array(await crypto.subtle.digest('SHA-256',encoder.encode(verifier))))
  return {state,verifier,challenge}
}

export function importDriveKey(encoded: string) {
  if (!driveNonce.test(encoded)) throw new Error('Drive encryption key configuration is invalid')
  const key = decode(encoded)
  if (key.length!==32 || base64url(key)!==encoded) throw new Error('Drive encryption key configuration is invalid')
  return crypto.subtle.importKey('raw',key,'AES-GCM',false,['encrypt','decrypt'])
}

export async function sealDriveToken(key: CryptoKey, context: string, value: string) {
  const iv = random(12)
  const sealed = await crypto.subtle.encrypt({name:'AES-GCM',iv,additionalData:encoder.encode(context)},key,encoder.encode(value))
  return base64url(iv)+'.'+base64url(new Uint8Array(sealed))
}

export async function openDriveToken(key: CryptoKey, context: string, sealed: string) {
  if (!/^[A-Za-z0-9_-]{16}\.[A-Za-z0-9_-]{23,6000}$/.test(sealed)) throw new Error('Drive credential is invalid')
  const [iv,value]=sealed.split('.')
  const bytes=await crypto.subtle.decrypt({name:'AES-GCM',iv:decode(iv),additionalData:encoder.encode(context)},key,decode(value))
  return new TextDecoder().decode(bytes)
}
