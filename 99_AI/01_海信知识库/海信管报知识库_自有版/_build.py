# -*- coding: utf-8 -*-
import re, json, os

SRC = "/Users/zhouhong/Documents/01_TA工作/99_AI/01_海信知识库/99_投喂文件/海信管报知识库_V17.html"
OUT = "/Users/zhouhong/Documents/01_TA工作/99_AI/01_海信知识库/海信管报知识库_自有版"

s = open(SRC, encoding="utf-8").read()

# ---- 1. 定位各边界 ----
head_end = s.index("</head>") + len("</head>")
kb_open = s.index('<script id="kbdata"')
kb_open_end = s.index(">", kb_open) + 1
kb_close = s.index("</script>", kb_open)
data_raw = s[kb_open_end:kb_close]          # 血缘数据（内嵌兜底）
skeleton = s[head_end:kb_open]              # body 骨架

viewer_open = s.index("<script>", kb_close)
viewer_open_end = s.index(">", viewer_open) + 1
viewer_close = s.rindex("</script>")
viewer_code = s[viewer_open_end:viewer_close]

# ---- 2. 目录型数据（同事库补充）----
ws_cat_raw = open(os.path.join(OUT, "ws_catalog.json"), encoding="utf-8").read()

# ---- 3. head：注入自有版样式 ----
head = s[:head_end]
head = head.replace("<title>海信管报知识库</title>",
                    "<title>海信管报知识库 · 自有可迭代版（血缘 + 目录）</title>")
head = head.replace("</style>", r"""
  /* ===== 自有版：迭代工具条 ===== */
  .kbbtn{font-family:var(--sans);font-size:12px;padding:4px 10px;border:1px solid rgba(255,255,255,.5);
    background:rgba(255,255,255,.16);color:#fff;border-radius:6px;cursor:pointer;white-space:nowrap;text-decoration:none}
  .kbbtn:hover{background:rgba(255,255,255,.3)}
  #kbAbout{position:fixed;inset:0;background:rgba(0,0,0,.45);display:none;z-index:200;
    align-items:center;justify-content:center}
  #kbAbout .box{background:#fff;max-width:640px;width:90%;max-height:80vh;overflow:auto;border-radius:10px;
    padding:22px 26px;font-size:13px;line-height:1.8;color:var(--txt)}
  #kbAbout h3{margin:0 0 10px;color:var(--brand-d)}
  #kbAbout code{background:#f1f4f5;padding:1px 6px;border-radius:4px;font-family:var(--mono);font-size:12px}
  #kbAbout .x{float:right;cursor:pointer;color:var(--txt3);font-size:18px}
  /* ===== 自有版：WS/Dataset 目录与架构（合并进同一导航） ===== */
  .gal{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px}
  .gitem{border:1px solid var(--line);border-radius:8px;overflow:hidden;background:#fff;cursor:pointer}
  .gitem img{width:100%;height:160px;object-fit:cover;display:block;background:#f1f4f5}
  .gitem .cap{padding:8px 10px;font-size:12px}
  .gitem .cap b{display:block;color:var(--brand-d);margin-bottom:2px}
  .lightbox{position:fixed;inset:0;background:rgba(0,0,0,.85);display:none;z-index:300;
    align-items:center;justify-content:center;flex-direction:column;padding:24px}
  .lightbox.on{display:flex}
  .lightbox img{max-width:94vw;max-height:78vh;border-radius:6px;background:#fff}
  .lightbox .cap{color:#fff;max-width:90vw;margin-top:10px;font-size:13px;text-align:center}
  .lightbox .x{position:absolute;top:16px;right:22px;color:#fff;font-size:26px;cursor:pointer}
  .ds{border:1px solid var(--line);border-radius:8px;margin-bottom:8px;overflow:hidden;background:#fff}
  .ds>.hd2{padding:10px 14px;cursor:pointer;display:flex;gap:10px;align-items:baseline;background:#fafcfc}
  .ds>.hd2:hover{background:var(--brand-l2)}
  .ds>.hd2 .code{font-family:var(--mono);font-weight:700;color:var(--brand-d)}
  .ds>.hd2 .nm{font-weight:600}
  .ds>.hd2 .rt{margin-left:auto;font-size:11px;color:var(--txt3);white-space:nowrap}
  .ds .body{padding:0 14px 12px;display:none}
  .ds.open .body{display:block}
  .badge{font-size:10.5px;padding:1px 7px;border-radius:9px;border:1px solid var(--line);
    color:var(--txt2);background:#f1f4f5;margin:0 2px 0 0}
  .badge.warn{color:var(--warn);border-color:#f6e0bf;background:#fdf3e5}
  .wsQ{font-size:13px;padding:7px 11px;border:1px solid var(--line);border-radius:6px;flex:1;min-width:220px}
</style>""")

# ---- 4. 改造查看器引擎：侧栏加「目录与架构」分组 + 路由分发新视图 ----
i = viewer_code.find("function renderNav(cur){")
j = viewer_code.find("function go(v,arg){")
assert -1 < i < j and j - i < 900, "renderNav 定位失败"
viewer_code = viewer_code[:i] + """function renderNav(cur){
  var side=q("side"); side.innerHTML="";
  side.appendChild(el("div","grp","知识库 · 血缘"));
  NAV.forEach(function(n){
    var a=el("a","nav"+(cur===n[0]?" on":""),"<span>"+n[1]+"</span>"+(n[2]!==""?'<span class="n">'+n[2]+"</span>":""));
    a.href="#"+n[0];
    a.onclick=function(ev){ ev.preventDefault(); go(n[0]); };
    side.appendChild(a);
  });
  if(typeof WSNAV!=="undefined" && WSNAV){
    side.appendChild(el("div","grp","目录与架构"));
    WSNAV.forEach(function(n){
      var a=el("a","nav"+(cur===n[0]?" on":""),"<span>"+n[1]+"</span>"+(n[2]!==""?'<span class="n">'+n[2]+"</span>":""));
      a.href="#"+n[0];
      a.onclick=function(ev){ ev.preventDefault(); go(n[0]); };
      side.appendChild(a);
    });
  }
}
""" + viewer_code[j:]

old_disp = "({ov:viewOv,tb:viewTb,ob:viewOb,ln:viewLn,fl:viewFl}[v]||viewOv)(M,arg);"
new_disp = ("({ov:viewOv,tb:viewTb,ob:viewOb,ln:viewLn,fl:viewFl,"
            "ws:viewWs,wsarch:viewWsArch,wsdir:viewWsDir}[v]||viewOv)(M,arg);")
assert old_disp in viewer_code, "路由分发定位失败"
viewer_code = viewer_code.replace(old_disp, new_disp)

viewer = '<script>\n' + viewer_code + '\n</script>\n'

# ---- 5. 内嵌两份数据 ----
embed_kb = '<script id="kbdata" type="application/json">' + data_raw + '</script>\n'
embed_ws = '<script id="wscat" type="application/json">' + ws_cat_raw + '</script>\n'

# ---- 6. WS 目录视图（函数名全部 ws 前缀，避免与 V17 冲突）----
ws_script = r'''<script>
/* ===== 合并进主导航的「目录与架构」视图 ===== */
var WSNAV=[["ws","WS/Dataset 图谱",""],["wsarch","架构图","13"],["wsdir","数据目录","125"]];
var WSCAT=JSON.parse(document.getElementById("wscat").textContent);
var WSFILTER="ALL", WSQ="";

function wsEsc(s){ return String(s==null?"":s).replace(/[&<>"]/g,function(c){return {"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c];}); }
function wsLB(){
  var b=document.getElementById("wsLb");
  if(!b){ b=document.createElement("div"); b.id="wsLb"; b.className="lightbox";
    b.innerHTML='<span class="x" onclick="document.getElementById(\'wsLb\').classList.remove(\'on\')">×</span><img id="wsLbImg" src=""><div class="cap" id="wsLbCap"></div>';
    document.body.appendChild(b); }
  return b;
}
function wsOpenImg(id){
  var it=null; WSCAT.illustrations.forEach(function(x){ if(x.id===id) it=x; });
  var b=wsLB();
  document.getElementById("wsLbImg").src="assets/arch/"+id+".png";
  document.getElementById("wsLbCap").innerHTML="<b>"+wsEsc(it?it.title:"")+"</b><br>"+wsEsc(it?it.note:"");
  b.classList.add("on");
}
function wsCard(k,v){ return '<div class="card"><div class="k">'+k+'</div><div class="v">'+v+'</div></div>'; }

/* —— 总览 —— */
function viewWs(M){
  var s=WSCAT.summary, m=WSCAT.meta;
  var h='<div class="hint">来源：'+wsEsc(m.source)+' ｜ 生成于 '+wsEsc(m.generatedAt)+' ｜ 状态 '+wsEsc(m.status)+'<br>'+wsEsc(m.note)+'</div>';
  h+='<div class="cards">'+wsCard("Workspace 数",s.workspaces.length)+wsCard("Dataset 数",s.datasetCount)
    +wsCard("字段数",s.fieldCount)+wsCard("架构图",s.imageCount)+wsCard("辅助命名表",s.auxCount)+'</div>';
  h+='<div class="panel"><div class="hd">各 Workspace 的 Dataset 分布</div><div class="bd"><table><thead><tr><th>Workspace</th><th>Dataset 数</th><th>字段数</th><th>主题</th></tr></thead><tbody>';
  s.workspaces.forEach(function(w){
    var ds=WSCAT.datasets.filter(function(d){return d.workspace===w;});
    var fc=ds.reduce(function(a,d){return a+(d.fieldCount||0);},0);
    var th={}; ds.forEach(function(d){ if(d.theme) th[d.theme]=(th[d.theme]||0)+1; });
    h+='<tr><td class="mono">'+w+'</td><td>'+ds.length+'</td><td>'+fc+'</td><td class="muted">'+(Object.keys(th).join("、")||"—")+'</td></tr>';
  });
  h+='</tbody></table></div></div>';
  h+='<div class="panel"><div class="hd">架构图清单（'+WSCAT.illustrations.length+'）</div><div class="bd"><table><thead><tr><th>编号</th><th>标题</th><th>说明</th><th>类型</th></tr></thead><tbody>';
  WSCAT.illustrations.forEach(function(it){
    h+='<tr><td class="mono">'+wsEsc(it.id)+'</td><td><b>'+wsEsc(it.title)+'</b></td><td class="muted">'+wsEsc(it.note||"")+'</td><td class="muted">'+wsEsc(it.kind||"")+'</td></tr>';
  });
  h+='</tbody></table></div></div>';
  h+='<div class="panel"><div class="hd">Workspace → 层 / 角色 映射</div><div class="bd"><table><thead><tr><th>Workspace</th><th>层</th><th>角色</th><th>依据</th></tr></thead><tbody>';
  WSCAT.architecture.forEach(function(a){ h+='<tr><td class="mono">'+wsEsc(a.workspace)+'</td><td>'+wsEsc(a.layer||"")+'</td><td>'+wsEsc(a.role||"")+'</td><td class="muted">'+wsEsc(a.basis||"")+'</td></tr>'; });
  h+='</tbody></table></div></div>';
  M.innerHTML=h;
}

/* —— 架构图 —— */
function viewWsArch(M){
  var h='<div class="hint">点击缩略图看大图。共 '+WSCAT.illustrations.length+' 张（总体→收入→成本→…→KPI）。</div><div class="gal">';
  WSCAT.illustrations.forEach(function(it){
    h+='<div class="gitem" onclick="wsOpenImg(\''+it.id+'\')"><img src="assets/arch/'+it.id+'.png" loading="lazy" alt="'+wsEsc(it.title)+'"><div class="cap"><b>'+wsEsc(it.title)+'</b><span class="muted">'+wsEsc((it.note||"").slice(0,40))+'…</span></div></div>';
  });
  M.innerHTML=h+'</div>';
}

/* —— 数据目录 —— */
function viewWsDir(M){
  var h='<div class="toolbar"><div>';
  h+='<span class="chip '+(WSFILTER==="ALL"?"on":"")+'" data-w="ALL">全部</span>';
  WSCAT.summary.workspaces.forEach(function(w){ h+='<span class="chip '+(WSFILTER===w?"on":"")+'" data-w="'+w+'">'+w+'</span>'; });
  h+='</div><input type="text" class="wsQ" id="wsDirQ" placeholder="搜索 Dataset 编码 / 名称 / 主题 / 物理表" value="'+wsEsc(WSQ)+'"></div>';
  var ds=WSCAT.datasets.filter(function(d){ return WSFILTER==="ALL"||d.workspace===WSFILTER; });
  if(WSQ){ var q=WSQ.toLowerCase();
    ds=ds.filter(function(d){ return (d.code||"").toLowerCase().indexOf(q)>=0 || (d.name||"").toLowerCase().indexOf(q)>=0
      || (d.theme||"").toLowerCase().indexOf(q)>=0 || (d.physicalTables||"").toLowerCase().indexOf(q)>=0; }); }
  h+='<div class="muted" style="margin-bottom:8px">命中 '+ds.length+' 个 Dataset</div>';
  if(!ds.length) h+='<div class="empty">无匹配</div>';
  ds.forEach(function(d){
    h+='<div class="ds" data-id="'+wsEsc(d.id)+'"><div class="hd2" onclick="wsToggleDs(this)">'
      +'<span class="code">'+wsEsc(d.code)+'</span><span class="nm">'+wsEsc(d.name||"")+'</span>'
      +'<span class="badge">'+wsEsc(d.workspace)+'</span>'
      +(d.theme?'<span class="badge">'+wsEsc(d.theme)+'</span>':'')
      +(d.status&&d.status!=="有效"?'<span class="badge warn">'+wsEsc(d.status)+'</span>':'')
      +'<span class="rt">字段 '+(d.fieldCount||0)+' · 物理表 '+(d.physicalCount||0)+'</span></div>'
      +'<div class="body" id="wsd-'+wsEsc(d.id)+'"></div></div>';
  });
  h+='<div class="panel" style="margin-top:14px"><div class="hd">辅助命名表（未纳入血缘，仅供参考）· '+WSCAT.auxiliary.length+'</div><div class="bd"><table><thead><tr><th>Workspace</th><th>物理表</th><th>字段数</th><th>状态</th><th>来源区间</th></tr></thead><tbody>';
  WSCAT.auxiliary.forEach(function(a){ h+='<tr><td class="mono">'+wsEsc(a.workspace)+'</td><td class="mono">'+wsEsc(a.table)+'</td><td>'+(a.fieldCount||"")+'</td><td class="muted">'+wsEsc(a.status||"")+'</td><td class="mono muted">'+(a.sourceRange||"")+'</td></tr>'; });
  h+='</tbody></table></div></div>';
  M.innerHTML=h;
  /* 筛选/搜索时直接重渲染本视图（不走 route()，避免每次都滚回页首、丢光标） */
  var VW=document.getElementById("view");
  M.querySelectorAll(".chip").forEach(function(c){ c.onclick=function(){ WSFILTER=c.dataset.w; viewWsDir(VW); }; });
  var qi=document.getElementById("wsDirQ");
  if(qi) qi.oninput=function(){ WSQ=qi.value; var pos=qi.selectionStart; viewWsDir(VW);
    var nq=document.getElementById("wsDirQ"); if(nq){ nq.focus(); nq.setSelectionRange(pos,pos); } };
}
function wsToggleDs(el){
  var ds=el.parentNode, id=ds.dataset.id, body=document.getElementById("wsd-"+id);
  if(ds.classList.toggle("open") && body && !body.dataset.loaded){
    var d=null; WSCAT.datasets.forEach(function(x){ if(x.id===id) d=x; });
    var f=WSCAT.fields.filter(function(x){ return x.datasetId===id; });
    var h='<div class="muted" style="margin:4px 0 8px">物理表：<span class="mono">'+wsEsc(d?d.physicalTables:"")+'</span> ｜ 来源：<span class="mono">'+(d?d.sourceRange:"")+'</span></div>';
    h+='<table><thead><tr><th>#</th><th>字段</th><th>类型</th><th>长度</th><th>可空</th><th>物理表</th><th>注释</th></tr></thead><tbody>';
    f.forEach(function(x){ h+='<tr><td class="muted">'+(x.position||"")+'</td><td class="mono">'+wsEsc(x.name)+'</td><td>'+wsEsc(x.type||"")+'</td><td>'+(x.length||"")+'</td><td>'+(x.nullable||"")+'</td><td class="mono muted">'+wsEsc(x.table||"")+'</td><td class="muted">'+wsEsc(x.comment||"")+'</td></tr>'; });
    h+='</tbody></table>';
    body.innerHTML=h; body.dataset.loaded="1";
  }
}

/* 本地服务器下用外部 ws_catalog.json 覆盖内嵌兜底 */
if(location.protocol!=="file:"){
  fetch("ws_catalog.json?t="+Date.now()).then(function(r){return r.json();}).then(function(j){
    WSCAT=j;
    if(["ws","wsarch","wsdir"].indexOf((location.hash||"").replace(/^#/,"").split("/")[0])>=0) route();
  }).catch(function(){});
}
/* WSNAV 已就绪，重跑路由让侧栏出现「目录与架构」分组 */
route();
</script>
'''

# ---- 7. 自有版工具条（顶栏按钮 + 关于）----
own = r'''<script>
(function(){
  var tb = document.querySelector('.topbar');
  if (tb) {
    var sub = tb.querySelector('.sub');
    if (sub) sub.textContent = '自有可迭代版 · 血缘 + 目录（单文件）';
    var box = document.createElement('div');
    box.style.cssText = 'margin-left:14px;display:flex;gap:6px;align-items:center';
    box.innerHTML =
      '<a class="kbbtn" href="#ws" style="text-decoration:none">📊 WS/Dataset 图谱</a>'+
      '<button class="kbbtn" id="btnReload">↻重新加载</button>'+
      '<button class="kbbtn" id="btnImport">⬇导入JSON</button>'+
      '<button class="kbbtn" id="btnExport">⬆导出JSON</button>'+
      '<button class="kbbtn" id="btnAbout">？迭代说明</button>'+
      '<input type="file" id="fileKB" accept=".json,application/json" style="display:none">';
    var stat = tb.querySelector('.stat');
    if (stat) tb.insertBefore(box, stat); else tb.appendChild(box);
  }
  function applyKB(nk){
    KB = nk;
    T = KB.T; C = KB.C; O = KB.O; D = KB.D; K = KB.K; WF = KB.WF; SRC = KB.SRC || [];
    var kd = document.getElementById('kbdata');
    if (kd) kd.textContent = JSON.stringify(nk);
    try { location.hash = 'ov'; } catch(e){}
    route();
  }
  document.getElementById('btnReload').onclick = function(){
    if (location.protocol === 'file:') {
      alert('当前是「双击打开」模式，浏览器禁止读取本地 json。\n请双击 启动知识库.command 起服务，或手动：\n  cd 本目录 && python3 -m http.server 8000\n然后访问 http://127.0.0.1:8000\n\n或直接用「导入JSON」。');
      return;
    }
    fetch('kbdata.json?t=' + Date.now()).then(function(r){ return r.json(); }).then(function(j){
      applyKB(j); alert('已从 kbdata.json 重新加载。');
    }).catch(function(e){ alert('重新加载失败：' + e); });
  };
  var fileKB = document.getElementById('fileKB');
  document.getElementById('btnImport').onclick = function(){ fileKB.click(); };
  fileKB.onchange = function(){
    var f = fileKB.files[0]; if (!f) return;
    var rd = new FileReader();
    rd.onload = function(){
      try { applyKB(JSON.parse(rd.result)); alert('已导入 ' + f.name + '。\n（内存生效；持久化请「导出JSON」存为 kbdata.json）'); }
      catch(e){ alert('JSON 解析失败：' + e); }
    };
    rd.readAsText(f, 'utf-8'); fileKB.value = '';
  };
  document.getElementById('btnExport').onclick = function(){
    var blob = new Blob([JSON.stringify(KB, null, 0)], {type:'application/json'});
    var a = document.createElement('a');
    a.href = URL.createObjectURL(blob); a.download = 'kbdata.json'; a.click();
    setTimeout(function(){ URL.revokeObjectURL(a.href); }, 1000);
  };
  var about = document.createElement('div');
  about.id = 'kbAbout';
  about.innerHTML = '<div class="box"><span class="x" onclick="document.getElementById(\'kbAbout\').style.display=\'none\'">×</span>'+
    '<h3>这是「我们自己的」海信管报知识库（单文件版）</h3>'+
    '<p>基于官方 V17 的血缘内容 + 同事库（WS/Dataset 图谱）的目录内容，<b>已合并为一个文件</b>；数据独立成文件、可迭代更新。</p>'+
    '<p><b>侧栏两块：</b><br>·「知识库 · 血缘」——总览 / 表字典 / 程序库 / 血缘关系 / 跑数链路<br>·「目录与架构」——WS/Dataset 图谱 / 架构图 / 数据目录（Workspace→Dataset→表→字段）</p>'+
    '<p><b>三种迭代方式：</b></p>'+
    '<p>① <b>改 kbdata.json 或 ws_catalog.json（推荐）</b>：双击 <code>启动知识库.command</code> 起服务后，改完刷新即生效。</p>'+
    '<p>② <b>导入/导出</b>：顶栏「⬇导入JSON」加载改好的文件（双击模式也能用）；「⬆导出JSON」存回持久化。</p>'+
    '<p>③ <b>让我来改</b>：把要增删改的内容告诉我，我直接更新数据并重新生成。</p>'+
    '<p class="muted">血缘数据与 V17 同源（179 程序 / 1204 表 / 37483 字段 / 9509 血缘边）；目录数据来自同事库（4 Workspace / 125 Dataset / 3448 字段 / 13 张架构图）。架构图为外部文件 <code>assets/arch/*.png</code>。</p>'+
    '</div>';
  document.body.appendChild(about);
  document.getElementById('btnAbout').onclick = function(){ about.style.display = 'flex'; };
  about.onclick = function(e){ if (e.target === about) about.style.display = 'none'; };

  if (location.protocol !== 'file:') {
    fetch('kbdata.json?t=' + Date.now()).then(function(r){ return r.json(); }).then(function(j){
      applyKB(j);
    }).catch(function(){});
  }
})();
</script>
'''

doc = head + skeleton + embed_kb + embed_ws + viewer + ws_script + own + "</body>\n</html>\n"
with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as f:
    f.write(doc)

print("OK")
print("index.html bytes:", os.path.getsize(os.path.join(OUT, "index.html")))
