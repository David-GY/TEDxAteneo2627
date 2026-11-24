type PickedFile = { id: string; resourceKey?: string }
type PickerTicket = { accessToken: string; appId: string; developerKey: string }
type PickerDialog = { setVisible(visible: boolean): void; dispose(): void }
type PickerBuilder = {
  addView(view: string): PickerBuilder
  setOAuthToken(token: string): PickerBuilder
  setAppId(id: string): PickerBuilder
  setDeveloperKey(key: string): PickerBuilder
  setOrigin(origin: string): PickerBuilder
  setMaxItems(max: number): PickerBuilder
  setCallback(callback: (event: {action?: string; docs?: Record<string,unknown>[]})=>void): PickerBuilder
  build(): PickerDialog
}
type GooglePicker = { PickerBuilder: new()=>PickerBuilder; ViewId: {DOCS: string}; Action: {PICKED: string; CANCEL: string} }
type PickerWindow = Window & {
  gapi?: {load(name: string, options: { callback: ()=>void; onerror: ()=>void; timeout: number; ontimeout: ()=>void }): void}
  google?: {picker?: GooglePicker}
}

let loading: Promise<GooglePicker> | undefined

function loadPicker() {
  if (loading) return loading
  const browser = window as PickerWindow
  loading = new Promise<GooglePicker>((resolve,reject)=>{
    const fail = ()=>reject(new Error('Drive Picker unavailable'))
    const load = ()=>{
      if (!browser.gapi) return fail()
      browser.gapi.load('picker',{
        callback:()=>browser.google?.picker?resolve(browser.google.picker):fail(),
        onerror:fail,timeout:8000,ontimeout:fail,
      })
    }
    if (browser.gapi) return load()
    const script=document.createElement('script')
    script.src='https://apis.google.com/js/api.js'
    script.async=true
    const timer=setTimeout(()=>{script.remove();fail()},8000)
    script.onload=()=>{clearTimeout(timer);load()}
    script.onerror=()=>{clearTimeout(timer);script.remove();fail()}
    document.head.append(script)
  }).catch(error=>{loading=undefined;throw error})
  return loading
}

export async function pickDriveFile(ticket: PickerTicket, origin: string, signal: AbortSignal) {
  const picker=await loadPicker()
  if (signal.aborted) return null
  return new Promise<PickedFile|null>((resolve,reject)=>{
    let dialog: PickerDialog | undefined
    function close() { dialog?.setVisible(false); dialog?.dispose(); signal.removeEventListener('abort',cancel) }
    function cancel() { close();resolve(null) }
    signal.addEventListener('abort',cancel,{once:true})
    try {
      dialog=new picker.PickerBuilder().addView(picker.ViewId.DOCS).setAppId(ticket.appId)
        .setDeveloperKey(ticket.developerKey).setOAuthToken(ticket.accessToken).setOrigin(origin).setMaxItems(1)
        .setCallback(event=>{
          if (event.action===picker.Action.CANCEL) return cancel()
          if (event.action!==picker.Action.PICKED) return
          close()
          const picked=event.docs?.[0]
          if (event.docs?.length!==1 || typeof picked?.id!=='string') return reject(new Error('Invalid Drive selection'))
          const resourceKey=typeof picked.resourceKey==='string'?picked.resourceKey:undefined
          resolve({id:picked.id,resourceKey})
        }).build()
      dialog.setVisible(true)
    } catch (error) { close();reject(error) }
  })
}
