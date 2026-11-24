import { driveRestBackend } from './backend.ts'
import { createGoogleDrive, DriveError } from './google.ts'
import { driveOAuthHandler } from './handler.ts'
import { importDriveKey } from './protocol.ts'
import { driveSelection } from './selection.ts'
import { createDriveRendition, type RenditionStage } from '../drive-export/rendition.ts'
import { restBackend } from '../files/backend.ts'
import { createDriveCopy } from '../drive-export/copy.ts'
import { createDriveCopyProvider } from '../drive-export/copy-provider.ts'

declare const Deno:{env:{get(name:string):string|undefined};serve(handler:(request:Request)=>Promise<Response>):void}

const settings = {
  origin:Deno.env.get('APP_ORIGIN'), dataOrigin:Deno.env.get('SUPABASE_URL'),
  anon:Deno.env.get('SUPABASE_ANON_KEY'), service:Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
  clientId:Deno.env.get('DRIVE_OAUTH_CLIENT_ID'), clientSecret:Deno.env.get('DRIVE_OAUTH_CLIENT_SECRET'),
  encryptionKey:Deno.env.get('DRIVE_OAUTH_ENCRYPTION_KEY'),
  pickerAppId:Deno.env.get('DRIVE_PICKER_APP_ID'), pickerKey:Deno.env.get('DRIVE_PICKER_BROWSER_KEY'),
}

if (Deno.env.get('DRIVE_OAUTH_ENABLED')!=='true' || !settings.origin || !settings.dataOrigin
  || !settings.anon || !settings.service || !settings.clientId || !settings.clientSecret || !settings.encryptionKey
  || !settings.pickerAppId || !settings.pickerKey) {
  Deno.serve(async()=>Response.json({error:{code:'unavailable'}},{status:503,headers:{'Cache-Control':'no-store'}}))
} else {
  const key=await importDriveKey(settings.encryptionKey)
  const google=createGoogleDrive({origin:settings.origin,clientId:settings.clientId,clientSecret:settings.clientSecret})
  const backend=driveRestBackend(settings.dataOrigin,settings.anon,settings.service)
  const picker={appId:settings.pickerAppId,developerKey:settings.pickerKey}
  const selection=driveSelection(backend,google,key,picker)
  const files=restBackend(settings.dataOrigin,settings.anon,settings.service)
  const jobs=restBackend(settings.dataOrigin,settings.service,settings.service)
  const rendition=Deno.env.get('DRIVE_RENDITION_ENABLED')==='true'
    ? createDriveRendition(backend,async (jwt,term,work,version,reserve,finish)=>{
      const value=await files.rpc(jwt,'drive_rendition_stage',{
        p_term_id:term,p_work_item_id:work,p_version:version??null,p_reserve_key:reserve??null,p_finish_key:finish??null,
      })
      if (!Number.isSafeInteger(value.version)) throw new DriveError('unavailable')
      return value as RenditionStage
    },files,google,key,picker) : undefined
  const copy=Deno.env.get('DRIVE_COPY_ENABLED')==='true'
    ? createDriveCopy(backend,files,(request,fileId,verified)=>jobs.rpc('Bearer '+settings.service,'drive_copy_job',{
      p_term_id:request.term,p_work_item_id:request.work,p_asset_id:request.asset,p_destination_id:request.destination,
      p_subject_id:request.subject,p_file_id:fileId??null,p_verified:verified??false,
    }),google,createDriveCopyProvider(),key) : undefined
  Deno.serve(driveOAuthHandler(backend,google,key,settings.origin,selection,rendition,copy))
}
