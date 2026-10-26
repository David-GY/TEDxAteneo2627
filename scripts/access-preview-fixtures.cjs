async function seedAccess(p){const f=await require('./access-fixtures.cjs').setupAccess(p);await f.admin();await f.ceiling();await f.custodian();return f}module.exports={seedAccess};
