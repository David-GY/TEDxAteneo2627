import {describe,it,expect} from 'vitest'
import {calendarDay,addDays,manilaDay,displayEndDay,schedule,windowFor,eventDay} from './dates'
describe('P16A_A2 date foundation (server/command acceptance remains pending)',()=>{
 it('keeps missing dates unscheduled and end-only records as deadline markers',()=>{
  expect(schedule(null,null,null)).toEqual({kind:'unscheduled',start:null,missing:'start_and_end'})
  expect(schedule('2027-01-01',null,null)).toEqual({kind:'unscheduled',start:'2027-01-01',missing:'end'})
  expect(schedule(null,'2027-04-17',null)).toEqual({kind:'deadline',end:eventDay})
 })
 it('uses inclusive days, accepts equal dates and rejects reversed ranges',()=>{
  expect(schedule('2027-04-17','2027-04-17',null)).toEqual({kind:'range',start:eventDay,end:eventDay,days:1})
  expect(schedule('2028-02-28','2028-03-01',null)).toMatchObject({days:3})
  expect(()=>schedule('2027-04-18',eventDay,null)).toThrow('Planned start')
 })
 it('derives timestamp deadlines from Manila midnight without rewriting them',()=>{
  expect(manilaDay('2026-12-31T15:59:59Z')).toBe('2026-12-31')
  expect(manilaDay('2026-12-31T16:00:00Z')).toBe('2027-01-01')
  expect(displayEndDay(null,'2028-02-28T16:00:00Z')).toBe('2028-02-29')
  expect(manilaDay('2027-04-17T00:00:00+08:00')).toBe(eventDay)
  expect(()=>manilaDay('2027-04-17T00:00:00')).toThrow('offset')
  expect(()=>displayEndDay(eventDay,'2027-04-17T00:00:00Z')).toThrow('one authoritative')
 })
 it('uses calendar arithmetic over leap days, month/year boundaries and early years',()=>{
  expect(addDays('2028-02-28',1)).toBe('2028-02-29');expect(addDays('2028-02-29',1)).toBe('2028-03-01')
  expect(addDays('2026-12-31',1)).toBe('2027-01-01');expect(addDays('2027-01-01',-1)).toBe('2026-12-31')
  expect(calendarDay('0099-01-01')).toBe('0099-01-01')
  for(const date of ['2027-02-29','2028-02-30','2027-13-01','0000-01-01','2027-4-01','not-a-date'])expect(()=>calendarDay(date)).toThrow()
  expect(()=>addDays(eventDay,0.5)).toThrow();expect(()=>addDays('9999-12-31',1)).toThrow()
 })
 it('produces Monday-based weeks and inclusive calendar months',()=>{
  expect(windowFor('2027-01-01','week')).toEqual({start:'2026-12-28',end:'2027-01-03'})
  expect(windowFor('2028-02-29','month')).toEqual({start:'2028-02-01',end:'2028-02-29'})
  expect(windowFor('2026-12-31','month')).toEqual({start:'2026-12-01',end:'2026-12-31'})
  expect(windowFor('9999-12-31','week').end).toBe('9999-12-31')
 })
})
