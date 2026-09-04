import{q as o,K as r,p as u}from"./index-CBr1m-EO.js";const y=e=>{const n=[e.context?`【背景】${e.context}`:"",e.selection?`【素材】
${e.selection}`:"",`【指令】${e.instruction}`].filter(Boolean);return[{role:"system",content:o("free-instruction","system")},{role:"user",content:n.join(`
`)}]},d=e=>{const n=Object.entries(e.fields).filter(([,t])=>String(t!=null?t:"").trim()).map(([t,s])=>`${t}：${s}`);return[{role:"system",content:o("naming","system")},{role:"user",content:`生成【${e.categoryLabel}】名字。
${n.join(`
`)}`}]},h=e=>{const n=Object.entries(e.info).filter(([,s])=>String(s!=null?s:"").trim()).map(([s,i])=>`${s}：${i}`),t=o("book-intro",e.mode==="generate"?"generateTask":"polishTask");return[{role:"system",content:o("book-intro","system")},{role:"user",content:[`【作品信息】
${n.join(`
`)}`,e.current?`【待润色简介】
${e.current}`:"",`【任务】${t}`].filter(Boolean).join(`
`)}]},m=e=>{const n=Object.entries(e.materials).filter(([,t])=>String(t!=null?t:"").trim()).map(([t,s])=>`【${t}】
${s}`);return[{role:"system",content:r("structured-analysis","system",{JSON形状:e.shape})},{role:"user",content:[n.join(`

`),`【任务】${e.task}${e.limit?`最多 ${e.limit} 条。`:""}`].join(`

`)}]},b=e=>{const n=e.kind==="outline"?o("reference-polish","outlineTask"):r("reference-polish","settingTask",{名称说明:e.name?`（「${e.name}」，类别：${e.typeLabel||"其他"}）`:""});return[{role:"system",content:o("reference-polish","richTextSystem")},{role:"user",content:`【原文】
${e.selection}
【任务】${n}`}]},$={appearance:"appearanceTask",personality:"personalityTask",background:"backgroundTask"},f=e=>[{role:"system",content:o("reference-polish","characterSystem")},{role:"user",content:`【原文】
${e.selection}
【任务】${o("reference-polish",$[e.field])}`}],a=e=>{var t,s;const n=[(t=e.recentTags)!=null&&t.length?`【最近的灵感标签】${e.recentTags.join("、")}`:"",(s=e.recentContents)!=null&&s.length?`【最近记下的灵感】
${e.recentContents.join(`
`)}`:"",`【任务】${o("inspiration","task")}`].filter(Boolean);return[{role:"system",content:o("inspiration","system")},{role:"user",content:n.join(`
`)}]},k=e=>{const n=o("editor-autocomplete",e.mode==="next_beat"?"nextBeat":"inline"),t=[e.chapterTitle?`【本章】${e.chapterTitle}`:"",e.chapterSummary?`【本章目标】${e.chapterSummary}`:"",e.sceneAnchor?`【场景锚点】${e.sceneAnchor}`:"",`【前文】
${e.preText}`,"从前文的断点处直接继续。"].filter(Boolean);return[{role:"system",content:`${o("editor-autocomplete","system")}
${n}`},{role:"user",content:t.join(`
`)}]},T=e=>u("editor-autocomplete",e==="next_beat"?"nextBeat":"inline"),j=e=>{const n=e.action==="custom"?r("editor-selection","custom",{指令:String(e.instruction||"").trim()}):o("editor-selection",e.action),t=[e.chapterTitle?`【本章】${e.chapterTitle}`:"",e.chapterSummary?`【本章目标】${e.chapterSummary}`:"",e.context?`【上下文】
${e.context}`:"",`【选中文本】
${e.selection}`].filter(Boolean);return[{role:"system",content:`${n}

${o("editor-selection","system")}`},{role:"user",content:t.join(`
`)}]},S=e=>u("editor-selection",e),x=e=>{const n=[],t=[o("miaobi","system"),String(e.modeInstruction||"").trim()].filter(Boolean).join(`

`);n.push({role:"system",content:t});for(const c of(e.history||[]).slice(-20)){const l=String(c.content||"").trim();l&&n.push({role:c.role==="ai"?"assistant":"user",content:l})}const s=String(e.context||"").trim(),i=String(e.query||"").trim();return n.push({role:"user",content:s?`${s}

${i}`:i}),n},L=e=>{var n,t;return[{role:"system",content:o("rank-report","system")},{role:"user",content:[`【榜单】${e.context}`,`【当前榜单】
${e.rankLines.join(`
`)}`,(n=e.changeLines)!=null&&n.length?`【名次变化】
${e.changeLines.join(`
`)}`:"",(t=e.categoryLines)!=null&&t.length?`【分类占比】
${e.categoryLines.join(`
`)}`:""].filter(Boolean).join(`

`)}]},M=e=>[{role:"system",content:o("cover-prompt","system")},{role:"user",content:[e.bookInfo?`【本书信息】
${e.bookInfo}`:"",`【风格】${e.style||"自动匹配"}；【色调】${e.tone||"自动匹配"}`,`【作者的描述】
${e.prompt}`].filter(Boolean).join(`

`)}];export{M as a,h as b,m as c,L as d,a as e,y as f,j as g,d as h,k as i,T as j,x as k,b as l,f as m,S as s};
