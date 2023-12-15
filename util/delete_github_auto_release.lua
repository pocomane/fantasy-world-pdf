#!/usr/bin/lua

-- Note: make sure you did:
--   git remote add origin git@github.com:user/repo.git

local f, e = io.popen("gh release list")
if not f then error(e) end
local ghrel_txt = f:read('a')
f:close()

local ghrel = {}
for line in ghrel_txt:gmatch('[^\n]+') do
  local row = {}
  ghrel[1+#ghrel] = row
  for column in line:gmatch('[^\t]*') do
    row[1+#row] = column
  end
end

print('deleting releases')
for r,l in ipairs(ghrel) do
  if "Latest" ~= l[2] and l[1]:match('release%.[a-zA-Z0-9]*$') then
    os.execute("gh release delete -y '"..l[1].."'")
  end
end

print('deleting tags')
for r,l in ipairs(ghrel) do
  if "Latest" ~= l[2] and l[1]:match('release%.[a-zA-Z0-9]*$') then
    os.execute(" git push origin --delete '"..l[1].."'")
  end
end

print('kept:')
os.execute("gh release list")

