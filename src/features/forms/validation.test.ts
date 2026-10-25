import {describe,it,expect} from 'vitest'
import {definition} from './form.test-data'
import {evaluateCondition,parseCentavos,validDefinition,validateForm,visibleValues} from './validation'
const options={members:[],units:[],files:[]}
describe('P20 browser validation',()=>{
 it('P20_A1 conditional requirements and newly hidden values are enforced without trusting old values',()=>{
  expect(validateForm(definition,{detail_needed:'yes'},options,false).errors.detail).toBe('required');expect(validateForm(definition,{detail_needed:'yes',detail:'Description'},options,false).valid).toBe(true);
  expect(validateForm(definition,{detail_needed:'no',detail:'Old hidden value'},options,false).errors.detail).toBe('hidden');expect(visibleValues(definition,{detail_needed:'no',detail:'Old hidden value'})).toEqual({detail_needed:'no'});
 });
 it('P20_A2 bounded schema and typed group evaluation reject executable input',()=>{
  expect(validDefinition({...definition,fields:[...definition.fields,...definition.fields]},false)).toBe(false);
  const malicious={...definition,script:'throw Error("executed")'};expect(validDefinition(malicious,false)).toBe(false);
  expect(evaluateCondition({op:'and',conditions:[{op:'gte',field:'number',value:1},{op:'or',conditions:[{op:'eq',field:'kind',value:'a'},{op:'in',field:'kind',value:['b','c']}]}]},{number:2,kind:'b'})).toBe(true);
 });
 it('keeps PHP centavos exact and rejects unsupported precision, signs and exponent syntax',()=>{
  expect(parseCentavos('123.45')).toBe(12345);expect(parseCentavos('0.01')).toBe(1);expect(parseCentavos('10')).toBe(1000);
  for(const s of['1.234','-1','1e3','Infinity','9,999','99999999999999.99'])expect(parseCentavos(s)).toBeNull();
 });
 it('rejects prototype-shaped unknown fields rather than silently accepting them',()=>{
  const r=validateForm(definition,JSON.parse('{"detail_needed":"no","__proto__":"bad","constructor":"bad"}'),options,false);expect(r.valid).toBe(false);expect(Object.keys(r.errors)).toEqual(['__proto__','constructor']);
 });
})
