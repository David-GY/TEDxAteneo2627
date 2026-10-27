// Reproduce reviewed authority-reader changes; locking and impact snapshots keep raw rows.
const fs=require('node:fs'),path=require('node:path');
const target='supabase/migrations/20261028000100_access_publication.sql',marker='-- AUTHORITY_CONSUMERS:';
const excluded=new Set(['app_private.lock_finance_scope','app_private.lock_publicity_scope','app_private.readiness_serialize','app_private.organization_fingerprint']);
const defs=new Map();
for(const file of fs.readdirSync('supabase/migrations').filter(n=>n.endsWith('.sql')&&n<path.basename(target)).sort()){
 for(const match of fs.readFileSync('supabase/migrations/'+file,'utf8').matchAll(/create\s+(?:or\s+replace\s+)?function\s+([\w.]+)\s*\([^;]*?\$\$([\s\S]*?)\$\$\s*;/gi))defs.set(match[1],match[0]);
}
const changed=[];
for(const[name,definition]of [...defs].sort(([a],[b])=>a.localeCompare(b))){
 if(!/\b(?:from|join)\s+public\.role_assignments\b/i.test(definition)||excluded.has(name))continue;
 const sql=definition.replace(/^create\s+(?:or\s+replace\s+)?function/i,'create or replace function').replace(/\b(from|join)\s+public\.role_assignments\b/gi,'$1 app_private.effective_role_assignments').replace('Validation only. Role/assignment publication and verified replacement enrollment are not implemented in this batch; no authority changed.','Validation only. Use the separately reviewed explicit publication path; this check changes no authority.');
 changed.push('-- '+name+' uses current delegation lineage.\n'+sql);
}
if(changed.length!==29)throw Error('Review authority consumer inventory: '+changed.length);
const original=fs.readFileSync(target,'utf8');
const tail=original.includes('-- ACCESS_READ_MODEL')?original.slice(original.indexOf('-- ACCESS_READ_MODEL')):'';
fs.writeFileSync(target,original.slice(0,original.indexOf(marker))+marker+' generated from explicit inventory; 29 current readers, four raw lock/fingerprint exceptions.\n'+changed.join('\n\n')+'\n'+tail);
console.log('Generated current-lineage consumers:',changed.map(x=>x.split('\n')[0]).join(', '));
