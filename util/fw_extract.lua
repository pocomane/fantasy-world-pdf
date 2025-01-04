
local BUILDDIR = "build"

local function exec(cmd)
  print('executing: '..cmd)
  if not os.execute(cmd) then
    error('command execution failed')
  end
end

local function load_file(path)
  local f, e = io.open(path, 'rb')
  if e then
    error('can not open '..path)
  end
  local c = f:read('a')
  f:close()
  return c
end

local function store_file(path, content)
  local f, e = io.open(path, "wb")
  if e then
    error('can not open '..path)
  end
  if content then f:write(content) end
  f:close()
end

local function prepare_deps()
  exec("mkdir -p '"..BUILDDIR.."'")
  if not pcall(load_file, BUILDDIR.."/weasyprint.done") then
    exec("cd '"..BUILDDIR.."' && curl -o dw.zip https://codeload.github.com/Kozea/WeasyPrint/zip/refs/tags/v60.2")
    exec("cd '"..BUILDDIR.."' && unzip dw.zip")
    exec("cd '"..BUILDDIR.."' && rm dw.zip")
    store_file(BUILDDIR..'/weasyprint.done')
  end
  if not pcall(load_file, BUILDDIR.."/pydyf.done") then
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

local function mergehtml(nm, ofs, addinfo)
  print('merging html pages...')

  local page = load_file(BUILDDIR..'/'..nm..'_tmp_001.html')

  local front, toc = '', ''
  if addinfo then
    front = '<div class="title_text">Fantasy World</div><div class="title_author">Alessandro Piroddi, Luca Maiorani, MS Edizioni, 2020-2023 - CC BY 4.0</div>\n\n<div class="PageBreak"></div>\n\n'
    toc =  load_file(BUILDDIR..'/'..nm..'_tmp_002.html')
  end

  store_file(BUILDDIR..'/'..nm.."_merged.html", front .. toc .. page)

  if not addinfo then
    exec('cp "'..BUILDDIR..'/'..nm..'_merged.html"'..' "'..BUILDDIR..'/'..nm..'.html"')
  else
    print('generating page numbering info...')
    exec('chmod ugo+x util/wp_wrap.py')
    pythonrun('util/wp_wrap.py "'..BUILDDIR..'/'..nm..'_merged.html" > "'..BUILDDIR..'/'..nm..'.inf"')
    local pg = load_file(BUILDDIR..'/'..nm..'.inf')
    local ref = {}
    for a, b in pg:gmatch('anchor ([0-9]+) ([^\n\r]+)') do
      ref[b] = a
    end
    toc = add_page_info(ofs, ref, toc)
    store_file(BUILDDIR..'/'..nm..".html", front .. toc .. page)
  end
end

local function htmltemplate(nm)
  print("applying html template...")
  local merged = load_file(BUILDDIR..'/'..nm..".html")
  local template = load_file('util/a5.html')
  local tmphtml = template:gsub("@{generate_html%(%)}", function() return merged end)
  store_file(BUILDDIR..'/'..nm.."_temp.html", tmphtml)
end

local function mdize(nm)

  local page = load_file(BUILDDIR..'/'..nm..'_temp.html')

  print('generating markdown...')

  page = page:gsub('^.-<p>', '<h1 id="04-the-world">The World</h1>\n\n<p>')
  page = page:gsub('</section>.*', '')
  page = page:gsub('<hr>[\n\r \t]*$', '')

  page = page:gsub('[ \t]*<hr>[\n\r \t]*<h([0-9]) [^>]*>([^<]*)</h[0-9]*>', function(a,b) return '\n'..('#'):rep(a=='1'and 1 or (tonumber(a)-1)).." "..b:gsub('^[ \t]*[0-9.]*[ \t]*%-[ \t]*','')..'\n' end)
  page = page:gsub('[ \t]*<h([0-9]) [^>]*>([^<]*)</h[0-9]*>', function(a,b) return '\n'..('#'):rep(a=='1'and 1 or (tonumber(a)-1)).." "..b:gsub('^[ \t]*[0-9.]*[ \t]*%-[ \t]*','')..'\n' end)
  page = page:gsub('<br>', "\n\n")
  page = page:gsub('<p>(.-)</p>', "%1\n\n")
  page = page:gsub('<em>(.-)</em>', "_%1_")
  page = page:gsub('<strong>(.-)</strong>', "__%1__")
  page = page:gsub('[ \t]*<blockquote>(.-)</blockquote>', "\n\n```\n%1\n```\n\n")

  local function recls(a, count, level)
    level = level or 0
    a = a:gsub('@ul(%b{})', function(a) return recls(a:sub(2,#a-1), '-', level + 1) end)
    a = a:gsub('@ol(%b{})', function(a) return recls(a:sub(2,#a-1), 0, level + 1) end)
    if '-' == count then
      a = a:gsub('<li>(.-)</li>', function(a)
        a = a:gsub('^[ \t\r\n]*', '')
        a = a:gsub('[ \t\r\n]*$', '')
        a = a:gsub('^_?_([^_]*)_?_$', '%1')
        return ("  "):rep(level).."- "..a
      end)
    end
    if 'number' == type(count) then
      a = a:gsub('<li>(.-)</li>', function(a)
        count = count + 1
        a = a:gsub('^[ \t\r\n]*', '')
        a = a:gsub('[ \t\r\n]*$', '')
        a = a:gsub('^_?_([^_]*)_?_$', '%1')
        return ("  "):rep(level)..tostring(count)..". "..a
      end)
    end
    return a
  end
  page = page:gsub('<([uo]l)>','@%1{')
  page = page:gsub('</([uo]l)>','}')
  page = recls(page)

  page = page:gsub('[ \t]*<table>(.-)</table>[ \t]*', function(t)
    local table = {}
    for r in t:gmatch('<tr>(.-)</tr>') do
      table[1+#table] = {}
      for c in r:gmatch('<td>(.-)</td>') do
        local row = table[#table]
        row[1+#row] = c:gsub('\r?\n',' '):gsub('^[ \t\r\n]*',''):gsub('[ \t\r\n]*$','')
      end
    end
    local result = '\n\n  <table>'
    for _, r in pairs(table) do
      result = result .. '<tr>'
      for _, c in pairs(r) do
        result = result .. '<td>\n\n'
        result = result .. c
        result = result .. '\n\n  </td>'
      end
      result = result .. '</tr>'
    end
    result = result .. '</table>\n\n'
    return result
  end)

  page = page:gsub('(\r?\n)[\n\r]+', "%1%1")

  page = page:gsub('&amp;', "&")
  page = page:gsub('&apos;', "'")
  page = page:gsub('&quot;', '"')
  page = page:gsub('&#x2019;', "'")
  page = page:gsub('&#x201[Cc];', '"')
  page = page:gsub('&#x201[Dd];', '"')
  page = page:gsub('&#x([0-9A-Fa-f][0-9A-Fa-f]);', function(a) return string.char(tonumber(a,16))  end)
  page = page:gsub('&#x([0-9A-Fa-f][0-9A-Fa-f])([0-9A-Fa-f][0-9A-Fa-f]);', function(a,b) return string.char(tonumber(a,16))..string.char(tonumber(b,16))  end)

  page = "\nLicensed under CC BY 4.0 by Alessandro Piroddi, Luca Maiorani, MS Edizioni, 2020-2023. Got from https://fantasyworldrpg.com\n" .. page

  local outmd = BUILDDIR.."/"..nm..".md"
  store_file(outmd, page)
  exec([[vim -n -c "set nocindent" -c "normal ggvGgq" -c wq "]]..outmd..[["]])

end

local function render(nm)
  print('rendering pdf...')
  pythonrun('-m weasyprint "'..BUILDDIR..'/'..nm..'_temp.html" "'..BUILDDIR..'/'..nm..'.pdf"')
end

local function scrape_and_render(nm, ofs, inp)

  scrape(nm, ofs, inp)
  mergehtml(nm, ofs, true)
  htmltemplate(nm)
  render(nm)
end

local function scrape_and_mdize(nm, ofs, inp)

  scrape(nm, ofs, inp)
  mergehtml(nm, ofs, false)
  exec('cp "'..BUILDDIR..'/'..nm..'_merged.html" "'..BUILDDIR..'/'..nm..'_temp.html"')
  mdize(nm)

end

local function md_html_pdf(nm)
  print('rendering md...')
  exec('markdown -ffencedcode "'..nm..'.md" > "'..BUILDDIR.. '"/'..nm..'.html')
  htmltemplate(nm)
  render(nm)
end

function main()

  prepare_deps()

  scrape_and_mdize("the_world_en", 2, {
    "http://fantasyworldrpg.com/eng/4-The-World.html",
  })

  scrape_and_mdize("il_mondo_ita", 1, {
    "http://fantasyworldrpg.com/ita/4-Il-Mondo.html",
  })

  md_html_pdf("the_world")

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

