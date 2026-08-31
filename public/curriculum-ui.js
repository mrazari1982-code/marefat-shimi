(function(root,factory){const api=factory();if(typeof module==='object'&&module.exports)module.exports=api;if(root)root.MarefatCurriculum=api;})(typeof globalThis==='undefined'?this:globalThis,function(){
  const num=v=>v===null||v===undefined||v===''?null:Number(v);
  function indexRows(rows){const all=(rows||[]).map(x=>({...x,id:Number(x.id),book_id:num(x.book_id),parent_id:num(x.parent_id)})),byId=new Map(all.map(x=>[x.id,x]));return{all,byId};}
  function children(index,parentId,type,bookId){const p=num(parentId),b=num(bookId);return index.all.filter(x=>x.parent_id===p&&x.node_type===type&&(b===null||x.book_id===b)).sort((a,z)=>Number(a.sort_order||0)-Number(z.sort_order||0)||a.id-z.id);}
  function path(index,id){const out=[],seen=new Set();let x=index.byId.get(Number(id));while(x&&!seen.has(x.id)){seen.add(x.id);out.unshift(x.name);x=x.parent_id===null?null:index.byId.get(x.parent_id);}return out.join(' / ');}
  function requiredLevels(kind){return kind==='konkur'?['chapter','topic','subtopic']:['chapter'];}
  function uniqueBooks(rows){const map=new Map();(rows||[]).forEach(x=>{const key=x.book_code||String(x.id);if(!map.has(key))map.set(key,x);});return [...map.values()].sort((a,b)=>Number(a.id)-Number(b.id));}
  return{indexRows,children,path,requiredLevels,uniqueBooks};
});
