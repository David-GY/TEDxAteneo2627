import {describe, expect, it} from 'vitest'
import {parseCsv, spreadsheetCsv, dryRun, templates, type Mapping} from './csv'

describe('P45 CSV preparation (no server commit)', () => {
  it('preserves UTF-8, BOM, quoted commas/newlines/quotes and calendar dates', () => {
    const input = '\uFEFFkey,title,due_on\r\n1,"Café, ""welcome""\nteam",2027-04-17\r\n'
    expect(parseCsv(input)).toEqual([['key','title','due_on'],['1','Café, "welcome"\nteam','2027-04-17']])
    expect(parseCsv(spreadsheetCsv([['é','one\ntwo','2027-04-17']]))).toEqual([['é','one\ntwo','2027-04-17']])
  })
  it('rejects malformed quotes, excessive size, nulls and excessive records before preview', () => {
    for (const value of ['a\n"unfinished', 'a\nb"c', 'a\n"b"x', 'a\n\0', 'a'.repeat(200001), Array(502).fill('a').join('\n')]) {
      expect(() => parseCsv(value)).toThrow()
    }
  })
  it('P45_A2 encoding regression: encloses every cell and neutralizes formula/control prefixes including hidden whitespace and full-width forms', () => {
    const values = ['=1+1','+SUM(A1)','-1+2','@SUM(A1)',' \t=1','\rtext','\ntext','＝1','＋1','－1','＠x','" ,=1']
    const encoded = spreadsheetCsv([values])
    const parsed = parseCsv(encoded)[0]
    for (let i=0;i<values.length-1;i++) expect(parsed[i]).toBe("'"+values[i])
    expect(parsed.at(-1)).toBe('" ,=1')
    expect(encoded).toContain('"" ,=1"')
  })
  const mapping: Mapping = {source_key:'key',title:'Work',due_on:'Date',reference:'Ref'}
  it('P45_U1 local repair retains mapping and issued refs; duplicate keys flag both rows and block the entire dry-run', () => {
    const initial = parseCsv('key,Work,Date,Ref\none,Signs,2027-02-29,TASK-027\none,Other,2027-04-17,TASK-028')
    const bad = dryRun('tasks',initial,mapping)
    expect(bad.valid).toBe(false)
    expect(bad.rows.map(r=>r.errors.some(e=>e.includes('Duplicate source key')))).toEqual([true,true])
    expect(bad.rows[0].errors.join(' ')).toContain('YYYY-MM-DD')
    const fixed = dryRun('tasks',parseCsv('key,Work,Date,Ref\none,Signs,2027-02-28,TASK-027\ntwo,Other,2027-04-17,TASK-028'),mapping)
    expect(fixed.valid).toBe(true)
    expect(fixed.rows[0].values.reference).toBe('TASK-027')
    expect(mapping.title).toBe('Work')
    expect(dryRun('tasks',initial,mapping)).toEqual(bad)
  })
  it('P45_A3 local defense: role/financial headers, duplicate mappings, missing keys and malformed roster emails cannot prepare changes', () => {
    for(const header of ['role','Admin','permissions','capability','amount','cost_centavos']) {
      expect(dryRun('tasks',parseCsv(`key,Work,${header}\na,Signs,admin`),mapping).valid).toBe(false)
    }
    expect(dryRun('tasks',parseCsv('key,Work,Date,Ref\na,Signs,2027-04-17,TASK-027'),{source_key:'key',title:'key'}).valid).toBe(false)
    expect(dryRun('tasks',[['key','Work'],['','Signs']],{source_key:'key',title:'Work'}).valid).toBe(false)
    expect(dryRun('roster',[['source_key','display_name','email'],['a','Ana','ana@student.ateneo.edu.evil']],{source_key:'source_key',display_name:'display_name',email:'email'}).valid).toBe(false)
    expect(dryRun('tasks',[['key','key'],['a','b']],mapping).valid).toBe(false)
  })
  it('templates prepare locally without assigning an identity, authority or a manually allocated reference', () => {
    for(const kind of ['tasks','roster'] as const) {
      const csv=parseCsv(templates[kind]);const map=Object.fromEntries(csv[0].map(h=>[h,h]))
      expect(dryRun(kind,csv,map).valid).toBe(true)
      expect(csv[0]).not.toContain('role')
    }
  })
})
