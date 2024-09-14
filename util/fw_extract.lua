#!/bin/lua

local BUILDDIR = "build"

local function exec(cmd)
  print('executing: '..cmd)
  if not os.execute(cmd) then
    error('command execution failed')
  end
end

local function load_file(path)
  local f, e = io.open(path, 'r')
  if e then
    return nil, 'can not find '..path
  end
  local c = f:read('a')
  f:close()
  return c
end

local function store_file(path, content)
  local f, e = io.open(path, "w")
  if e then
    error('can not open '..path)
  end
  if content then f:write(content) end
  f:close()
end

local function prepare_deps()
  exec("mkdir -p '"..BUILDDIR.."'")
  if not load_file(BUILDDIR.."/weasyprint.done") then
    exec("cd '"..BUILDDIR.."' && curl -o dw.zip https://codeload.github.com/Kozea/WeasyPrint/zip/refs/tags/v60.2")
    exec("cd '"..BUILDDIR.."' && unzip dw.zip")
    exec("cd '"..BUILDDIR.."' && rm dw.zip")
    store_file(BUILDDIR..'/weasyprint.done')
  end
  if not load_file(BUILDDIR.."/pydyf.done") then
    exec("cd '"..BUILDDIR.."' && curl -o dw.zip https://codeload.github.com/CourtBouillon/pydyf/zip/refs/tags/v0.8.0")
    exec("cd '"..BUILDDIR.."' && unzip dw.zip")
    exec("cd '"..BUILDDIR.."' && rm dw.zip")
    store_file(BUILDDIR..'/pydyf.done')
  end
end

local function pythonrun(args)
  exec([[export PYTHONPATH="]]..BUILDDIR..[[/WeasyPrint-60.2:]]..BUILDDIR..[[/pydyf-0.8.0:$PYTHONPATH"; python3 ]]..args)
end

local function extract_content(part)
  return part:match("<section[^>]*>(.*)</section>")
end

local function split_toc(part)
  local toc, tit
  part = part:gsub(
    '<h[1-9] (id="[^"]-">)(.-)</h[1-9]>(.-)(<h[1-9] id="[^"]-">)',
    function(a1,a2,a3,a4,a5)
      -- tit, toc = a2, a3
      -- return '<h1 '..a1..a2..'</h1>'..a4
      local rest 
      toc, rest = a3:match('^(.-)(<p>.*)$')
      toc = toc or a3
      rest = rest or ''
      tit, toc = a2, toc
      return '<h1 '..a1..a2..'</h1>'..rest..a4
    end,
    1
  )
  return part, toc, tit
end

local function add_part(page, part)
  page = page .. '\n\n<div class="PageBreak"></div>\n\n'
  page = page .. part
  page = page .. '\n\n'
  return page
end

local function add_toc(toc, title, index)
  toc = toc .. '\n\n'
  toc = toc .. '<h2>' .. title .. '</h2>'
  toc = toc .. '\n\n'
  toc = toc .. index
  toc = toc .. '\n\n'
  return toc
end

local function add_page_info(ofs, ref, toc)
  return toc:gsub(
    '(<li><a href="#)([^"]*)(">.-)(</a>)',
    function(a,b,c,d)
      return a..b..c..( ref[b] and (' ... p'..math.floor(ref[b]+ofs)) or'')..d
    end
  )
end

local function scrape(nm, ofs, inp)

  local tocref = '<a href="#reference-toc"><div class="page-toc-ref"></div></a>'
  local toc = '\n'..tocref..'<div class="toc" id="reference-toc">\n<h2>Table of the contents<h2>\n\n'
  local page = '</div>\n\n'

  local http = require 'socket.http'
  for _, url in ipairs(inp) do
    print('retriving from the web...')
    local part = http.request(url)

    print('partial parsing...')
    local itoc, ttoc

    part = extract_content(part)
    part, itoc, ttoc = split_toc(part)
    page = add_part(page, part)
    toc = add_toc(toc, ttoc, itoc)

  end
  store_file(BUILDDIR..'/'..nm..'_tmp_001.html', page)
  store_file(BUILDDIR..'/'..nm..'_tmp_002.html', toc)
end

local function render(nm, ofs)
  
  local front = '<div class="title_text">Fantasy World</div><div class="title_author">Alessandro Piroddi, Luca Maiorani, MS Edizioni, 2020-2023 - CC BY 4.0</div>\n\n<div class="PageBreak"></div>\n\n'

  local page = load_file(BUILDDIR..'/'..nm..'_tmp_001.html') 
  local toc =  load_file(BUILDDIR..'/'..nm..'_tmp_002.html') 

  local template = load_file('util/a5.html')

  local outhtml = template:gsub("@{generate_html%(%)}", function() return front .. toc .. page end)

  store_file(BUILDDIR..'/'..nm..".html", outhtml)

  -- print('generating page numbering info...')
  -- exec('chmod ugo+x util/wp_wrap.py')
  -- pythonrun('util/wp_wrap.py "'..BUILDDIR..'"/'..nm..'.html > "'..BUILDDIR..'"/'..nm..'.inf')
  -- local pg = load_file(BUILDDIR..'/'..nm..'.inf')
  -- local ref = {}
  -- for a, b in pg:gmatch('anchor ([0-9]+) ([^\n\r]+)') do
  --   ref[b] = a
  -- end
  -- toc = add_page_info(ofs, ref, toc)

  local tmphtml = template:gsub("@{generate_html%(%)}", function() return front .. toc .. page end)
  store_file(BUILDDIR..'/'..nm.."_temp.html", tmphtml)

  print('rendering pdf...')
  pythonrun('-m weasyprint "'..BUILDDIR..'"/'..nm..'_temp.html "'..BUILDDIR..'"/'..nm..'.pdf')
end

local function scrape_and_render(nm, ofs, inp)

  scrape(nm, ofs, inp)
  render(nm, ofs)
end

function main()

  prepare_deps()
  
  scrape_and_render("fantasy_world_en", 2, {
    "http://fantasyworldrpg.com/eng/1-Fundamental-Knowledge.html",
    "http://fantasyworldrpg.com/eng/2-Essential-Mechanics.html",
    "http://fantasyworldrpg.com/eng/3-The-First-Session.html",
    "http://fantasyworldrpg.com/eng/4-The-World.html",
    "http://fantasyworldrpg.com/eng/5-Game-Moves.html",
    "http://fantasyworldrpg.com/eng/6-Changing-the-Rules.html",
  })
  
  scrape_and_render("fantasy_world_ita", 1, {
    "http://fantasyworldrpg.com/ita/1-Nozioni-Fondamentali.html",
    "http://fantasyworldrpg.com/ita/2-Meccaniche-Essenziali.html",
    "http://fantasyworldrpg.com/ita/3-La-Prima-Sessione.html",
    "http://fantasyworldrpg.com/ita/4-Il-Mondo.html",
    "http://fantasyworldrpg.com/ita/5-Mosse-di-Gioco.html",
    "http://fantasyworldrpg.com/ita/6-Cambiare-le-Regole.html",
  })
end

main()

