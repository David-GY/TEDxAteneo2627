const assert = require('node:assert/strict')
const fs = require('node:fs/promises')
const { createIdentityDatabase } = require('./identity-db.cjs')

;(async () => {
  const { db } = await createIdentityDatabase()
  try {
    const { rows: columns } = await db.query(`select c.relname as table_name, a.attname as column_name,
      t.typname as type, a.attnotnull as required, a.atthasdef as has_default, a.attgenerated <> '' as generated
      from pg_attribute a join pg_class c on c.oid = a.attrelid
      join pg_namespace n on n.oid = c.relnamespace join pg_type t on t.oid = a.atttypid
      where n.nspname = 'public' and c.relkind = 'r' and a.attnum > 0 and not a.attisdropped
      order by c.relname, a.attnum`)
    const { rows: foreignKeys } = await db.query(`select c.relname as table_name, con.conname as name,
      target.relname as target, target_ns.nspname as target_schema,
      array(select a.attname from unnest(con.conkey) with ordinality as k(num, ord)
        join pg_attribute a on a.attrelid = c.oid and a.attnum = k.num order by k.ord) as columns,
      array(select a.attname from unnest(con.confkey) with ordinality as k(num, ord)
        join pg_attribute a on a.attrelid = target.oid and a.attnum = k.num order by k.ord) as target_columns,
      exists(select 1 from pg_constraint u where u.conrelid = c.oid and u.contype in ('p','u')
        and u.conkey <@ con.conkey) as one_to_one
      from pg_constraint con join pg_class c on c.oid = con.conrelid
      join pg_namespace n on n.oid = c.relnamespace join pg_class target on target.oid = con.confrelid
      join pg_namespace target_ns on target_ns.oid = target.relnamespace
      where n.nspname = 'public' and con.contype = 'f' order by c.relname, con.conname`)
    const { rows: functions } = await db.query(`select p.proname as name, p.pronargdefaults as defaults,
      p.proretset as returns_set, result.typname as result_type,
      coalesce((select jsonb_agg(jsonb_build_object('name',p.proargnames[a.ord], 'type',t.typname,
        'mode',coalesce(p.proargmodes[a.ord],'i')) order by a.ord)
        from unnest(coalesce(p.proallargtypes,p.proargtypes::oid[])) with ordinality a(oid,ord)
        join pg_type t on t.oid=a.oid),'[]'::jsonb) as args
      from pg_proc p join pg_namespace n on n.oid=p.pronamespace join pg_type result on result.oid=p.prorettype
      where n.nspname='public' and result.typname <> 'trigger' order by p.proname`)
    const scalar = { uuid: 'string', _uuid: 'string[]', text: 'string', timestamptz: 'string', date: 'string', bool: 'boolean', int4: 'number', int8: 'number', jsonb: 'Json' }
    const typeOf = (name) => { assert(scalar[name], `Unknown PostgreSQL type: ${name}`); return scalar[name] }
    const tables = [...new Set(columns.map((column) => column.table_name))]
    assert.equal(tables.length, 83)
    const lines = [
      '// Generated from the migrated PostgreSQL catalog by pnpm db:types. Do not edit.',
      '// Supabase-compatible table shape; full Supabase CLI comparison awaits Docker.',
      'export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]',
      '', 'export type Database = {', '  public: {', '    Tables: {',
    ]
    for (const table of tables) {
      lines.push(`      ${table}: {`)
      for (const mode of ['Row', 'Insert', 'Update']) {
        lines.push(`        ${mode}: {`)
        for (const column of columns.filter((column) => column.table_name === table)) {
          assert(scalar[column.type], `Unknown PostgreSQL type: ${column.type}`)
          const generated = column.generated && mode !== 'Row'
          const optional = mode === 'Update' || (mode === 'Insert' && (!column.required || column.has_default || generated))
          const type = generated ? 'never' : scalar[column.type] + (column.required ? '' : ' | null')
          lines.push(`          ${column.column_name}${optional ? '?' : ''}: ${type}`)
        }
        lines.push('        }')
      }
      lines.push('        Relationships: [')
      for (const fk of foreignKeys.filter((fk) => fk.table_name === table && fk.target_schema === 'public')) {
        lines.push('          {', `            foreignKeyName: ${JSON.stringify(fk.name)}`,
          `            columns: ${JSON.stringify(fk.columns)}`, `            isOneToOne: ${fk.one_to_one}`,
          `            referencedRelation: ${JSON.stringify(fk.target)}`, `            referencedColumns: ${JSON.stringify(fk.target_columns)}`, '          },')
      }
      lines.push('        ]', '      }')
    }
    lines.push('    }', '    Views: { [_ in never]: never }', '    Functions: {')
    for (const fn of functions) {
      const inputs = fn.args.filter((arg) => arg.mode === 'i')
      const outputs = fn.args.filter((arg) => arg.mode === 't')
      lines.push(`      ${fn.name}: {`, inputs.length ? '        Args: {' : '        Args: Record<string, never>')
      inputs.forEach((arg, index) => {
        const optional = index >= inputs.length - fn.defaults
        lines.push(`          ${arg.name}${optional ? '?' : ''}: ${typeOf(arg.type)}${optional ? ' | null' : ''}`)
      })
      if (inputs.length) lines.push('        }')
      if (outputs.length) {
        lines.push('        Returns: {')
        for (const arg of outputs) lines.push(`          ${arg.name}: ${typeOf(arg.type)}`)
        lines.push('        }[]')
      } else {
        assert(!fn.returns_set, 'Extend generator before adding scalar set-returning functions')
        lines.push(`        Returns: ${typeOf(fn.result_type)} | null`)
      }
      lines.push('      }')
    }
    lines.push('    }', '    Enums: { [_ in never]: never }', '    CompositeTypes: { [_ in never]: never }', '  }', '}', '')
    const output = lines.join('\n')
    const file = 'src/lib/database.types.ts'
    if (process.argv.includes('--check')) assert.equal(await fs.readFile(file, 'utf8'), output, 'Generated database types drifted; run pnpm db:types')
    else await fs.writeFile(file, output)
    console.log(`${process.argv.includes('--check') ? 'Verified' : 'Generated'} catalog types for ${tables.length} tables (${columns.length} columns) and ${functions.length} functions.`)
  } finally { await db.close() }
})().catch((error) => { console.error(error.code || 'GENERATION_FAILED', error.message); process.exitCode = 1 })
