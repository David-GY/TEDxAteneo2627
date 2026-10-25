import {expect,it} from 'vitest'
import {calculatePlan,emptyPlan,phpText} from './intake'
it('P25_A2 partial edits invalidate only their line and recompute exact totals',()=>{
 const d=emptyPlan('33333333-3333-4333-8333-333333333332');d.purpose='Plan';d.fundSource='Fund';d.termsRisks='Terms';d.lines=[{description:'First',quantity:'1',amount:'0.10'},{description:'Second',quantity:'1',amount:'0.20'}]
 expect(calculatePlan(d).payload?.requestedTotalCentavos).toBe('30')
 d.lines[0].quantity='';expect(calculatePlan(d).errors['lines.0.quantity']).toBeTruthy();expect(calculatePlan(d).total).toBeNull()
 d.lines[0].quantity='0.005';d.lines[0].amount='1.00';expect(calculatePlan(d).total).toBe('21')
 expect(phpText('9007199254740991')).toBe('90071992547409.91')
})
it('P25_A1 zero-cost fundraiser still produces a typed FIN payload',()=>{
 const d=emptyPlan('33333333-3333-4333-8333-333333333332');Object.assign(d,{kind:'fundraising',purpose:'Zero cost fundraiser',fundSource:'No costs',termsRisks:'School requirements pending',price:'0',forecastQuantity:'0'});d.lines=[{description:'No cost',quantity:'1',amount:'0'}]
 const c=calculatePlan(d);expect(c.errors).toEqual({});expect(c.payload?.kind).toBe('fundraising');expect(c.total).toBe('0');expect(c.revenue).toBe('0')
})
