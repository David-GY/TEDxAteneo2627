// Strings cross the API boundary; BigInt is used only while calculating.
const MAX_CENTAVOS = 9007199254740991n

function bounded(value: bigint): string {
  if (value < 0n || value > MAX_CENTAVOS) throw new Error('Amount is outside the supported centavo range')
  return value.toString()
}

function centavos(value: string): bigint {
  if (typeof value !== 'string' || !/^(0|[1-9]\d{0,15})$/.test(value)) throw new Error('Use integer centavos')
  const amount = BigInt(value)
  bounded(amount)
  return amount
}

export function parsePhp(value: string): string {
  if (typeof value !== 'string' || !/^(0|[1-9]\d{0,13})(\.\d{1,2})?$/.test(value)) throw new Error('Use a nonnegative PHP amount with at most two decimal places')
  const [whole, fraction = ''] = value.split('.')
  return bounded(BigInt(whole) * 100n + BigInt(fraction.padEnd(2, '0')))
}

function quantityTotal(quantity: string, unitAmountCentavos: string, allowZero: boolean): string {
  if (typeof quantity !== 'string' || !/^(0|[1-9]\d{0,6})(\.\d{1,3})?$/.test(quantity)) throw new Error('Use a positive quantity with at most three decimal places')
  const [whole, fraction = ''] = quantity.split('.')
  const milli = BigInt(whole) * 1000n + BigInt(fraction.padEnd(3, '0'))
  if (milli < (allowZero ? 0n : 1n) || milli > 1000000000n) throw new Error('Quantity is outside the supported range')
  return bounded((milli * centavos(unitAmountCentavos) + 500n) / 1000n)
}

export function lineTotal(quantity: string, unitAmountCentavos: string): string {
  return quantityTotal(quantity, unitAmountCentavos, false)
}

export function sumCentavos(values: readonly string[]): string {
  return bounded(values.reduce((total, value) => total + centavos(value), 0n))
}

export function forecastRevenue(quantity: string, unitPriceCentavos: string): string {
  return quantityTotal(quantity, unitPriceCentavos, true)
}
