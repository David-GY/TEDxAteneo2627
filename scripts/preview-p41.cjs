// Disposable in-memory notification fixtures; no clock/cadence or external transport.
require('./preview-p08.cjs').createPreview({port:5179,authoring:true,tasks:true,financeAuthorityPreview:true,notificationPreview:true})
 .then(async p=>{await require('./notification-preview-fixtures.cjs').seedNotificationPreview(p);console.log('P41 synthetic no-send proposal preview '+p.url+'/notifications; no live schedule or external delivery')})
 .catch(e=>{console.error(e.code,e.message);process.exitCode=1})
