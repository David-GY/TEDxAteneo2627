import{render,cleanup,fireEvent,screen}from'@testing-library/react'
import{afterEach,it,vi,expect}from'vitest'
import{WorkView}from'./WorkView'
afterEach(()=>{cleanup();vi.restoreAllMocks()})
it('records an explicitly opened visible work page once, without counting background scope checks',async()=>{
 const record=vi.fn().mockResolvedValue(undefined)
 const view=render(<WorkView allowed record={record}/>);await vi.waitFor(()=>expect(record).toHaveBeenCalledTimes(1))
 fireEvent.focus(window);view.rerender(<WorkView allowed={false} record={record}/>);view.rerender(<WorkView allowed record={record}/>);expect(record).toHaveBeenCalledTimes(1)
 expect(screen.queryByRole('alert')).toBeNull()
})
it('a background page waits for visibility before recording a work opening',async()=>{
 const visible=vi.spyOn(document,'visibilityState','get').mockReturnValue('hidden'),record=vi.fn().mockResolvedValue(undefined)
 render(<WorkView allowed record={record}/>);expect(record).not.toHaveBeenCalled();visible.mockReturnValue('visible');fireEvent(document,new Event('visibilitychange'));await vi.waitFor(()=>expect(record).toHaveBeenCalledTimes(1))
})
