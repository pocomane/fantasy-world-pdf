#!/bin/lua

local function exec(cmd)
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
  local f = io.open(path, "w")
  if e then
    return nil, 'can not open '..path
  end
  f:write(content)
  f:close()
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

local function main(nm, ofs, inp)
  exec('mkdir -p build')

  local front = '<div class="title_text">Fantasy World</div><div class="title_author">Alessandro Piroddi, Luca Maiorani, MS Edizioni, 2020-2023 - CC BY 4.0</div>\n\n<div class="PageBreak"></div>\n\n'
  local toc = '<div class="toc">\n<h2>Table of the contents<h2>\n\n'
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
  store_file('build/'..nm..'_tmp_001.html', page)
  store_file('build/'..nm..'_tmp_002.html', toc)

  local page = load_file('build/'..nm..'_tmp_001.html') 
  local toc = load_file('build/'..nm..'_tmp_002.html') 

  local template = load_file('util/a5.html')

  local outhtml = template:gsub("@{generate_html%(%)}", function() return front .. toc .. page end)

  store_file("build/"..nm..".html", outhtml)

  print('generating page numbering info...')
  exec('chmod ugo+x util/wp_wrap.py')
  exec('util/wp_wrap.py build/'..nm..'.html > build/'..nm..'.inf')
  local pg = load_file('build/'..nm..'.inf')
  local ref = {}
  for a, b in pg:gmatch('anchor ([0-9]+) ([^\n\r]+)') do
    ref[b] = a
  end
  toc = add_page_info(ofs, ref, toc)

  local tmphtml = template:gsub("@{generate_html%(%)}", function() return front .. toc .. page end)
  store_file("build/"..nm.."_temp.html", tmphtml)

  print('rendering pdf...')
  exec('weasyprint build/'..nm..'_temp.html build/'..nm..'.pdf')
end

main("fantasy_world_en", 2, {
  "http://fantasyworldrpg.com/eng/1-Fundamental-Knowledge.html",
  "http://fantasyworldrpg.com/eng/2-Essential-Mechanics.html",
  "http://fantasyworldrpg.com/eng/3-The-First-Session.html",
  "http://fantasyworldrpg.com/eng/4-The-World.html",
  "http://fantasyworldrpg.com/eng/5-Game-Moves.html",
  "http://fantasyworldrpg.com/eng/6-Changing-the-Rules.html",
})

main("fantasy_world_ita", 1, {
  "http://fantasyworldrpg.com/ita/1-Nozioni-Fondamentali.html",
  "http://fantasyworldrpg.com/ita/2-Meccaniche-Essenziali.html",
  "http://fantasyworldrpg.com/ita/3-La-Prima-Sessione.html",
  "http://fantasyworldrpg.com/ita/4-Il-Mondo.html",
  "http://fantasyworldrpg.com/ita/5-Mosse-di-Gioco.html",
  "http://fantasyworldrpg.com/ita/6-Cambiare-le-Regole.html",
})

