import { describe, expect, it } from 'vitest'
import { parsePhp, lineTotal, sumCentavos, forecastRevenue } from './money'

describe('P24_A1 exact PHP money', () => {
  it('adds 0.10 and 0.20 without floating arithmetic', () => {
    expect(sumCentavos([parsePhp('0.10'), parsePhp('0.20')])).toBe('30')
  })
  it('rounds each positive quantity product half up at centavos', () => {
    expect(lineTotal('0.005', '100')).toBe('1')
    expect(lineTotal('0.004', '100')).toBe('0')
    expect(lineTotal('1.125', '100')).toBe('113')
    expect(sumCentavos([lineTotal('0.005', '100'), lineTotal('0.005', '100')])).toBe('2')
    expect(forecastRevenue('2.500', '101')).toBe('253')
    expect(forecastRevenue('0', '101')).toBe('0')
  })
  it('preserves the maximum centavo value as a decimal string', () => {
    expect(parsePhp('90071992547409.91')).toBe('9007199254740991')
    expect(lineTotal('1', '9007199254740991')).toBe('9007199254740991')
  })
  it('rejects negatives, exponent notation, malformed and out-of-range inputs', () => {
    for (const value of ['-0.10', '0.001', '1e2', 'NaN', ' 1', '01', '90071992547409.92']) expect(() => parsePhp(value)).toThrow()
    for (const qty of ['0', '-1', '1.0001', '1e2', '1000000.001']) expect(() => lineTotal(qty, '1')).toThrow()
    for (const cents of ['-1', '1.0', '01', '9007199254740992']) expect(() => lineTotal('1', cents)).toThrow()
    expect(() => sumCentavos(['9007199254740991', '1'])).toThrow()
    expect(() => lineTotal('2', '9007199254740991')).toThrow()
  })
})
