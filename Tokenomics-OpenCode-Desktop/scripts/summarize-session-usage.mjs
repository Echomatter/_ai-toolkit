// Deterministic audit of existing exports, no provider calls or account snapshots.
// node scripts/summarize-session-usage.mjs PARENT_EXPORT CHILD_EXPORT...
import {readFile} from 'node:fs/promises';
import {summarizeSessions} from '../tools/runtime/usage.mjs';
const files=process.argv.slice(2);
if(!files.length)throw Error('Provide parent and child OpenCode export paths.');
const data=await Promise.all(files.map(async file=>JSON.parse((await readFile(file,'utf8')).replace(/^\uFEFF/,''))));
console.log(JSON.stringify(summarizeSessions(data,data[0].info.id),null,2));
