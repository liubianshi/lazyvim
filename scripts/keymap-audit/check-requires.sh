#!/usr/bin/env bash
# 检查全仓库对「本仓库自有模块」的 require 是否都能在 runtimepath 上解析。
#
# 存在的理由：模块搬家时，Lua 侧的 require("x") 容易一眼看全，但 autoload/*.vim
# 里还有三种写法会漏网——luaeval('require"x".f()')、v:lua.require'x'.f()、
# exec 'lua require("x").f()'。批次四就因为只扫 Lua 侧，把三个仍被 vimscript
# 调用的导出当成零引用删掉了。这个脚本把两侧一起扫。
#
# 用法：bash scripts/keymap-audit/check-requires.sh
# 输出：不可解析的模块名，一行一个；全部正常则输出 ALL RESOLVABLE。

set -euo pipefail
cd "$(dirname "$0")/../.."

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# 本仓库自有的顶层命名空间。插件模块（snacks / lazy / r.send 等）不在此列，
# 它们由 lazy.nvim 按需安装，未装时无法解析属正常情况。
OWN='^(lbs|util|translate|config|overseer|global_functions)\b'

find . -type d -name '.git' -prune -o -type f \( -name '*.lua' -o -name '*.vim' -o -name '*.md' \) -print |
	xargs perl -ne 'while (/(?:v:lua\.)?require\s*\(?\s*["\x27]([A-Za-z0-9_.]+)["\x27]/g) { print "$1\n" }' 2>/dev/null |
	perl -ne "print if /$OWN/" |
	sort -u >"$TMP/mods.txt"

cat >"$TMP/check.lua" <<'LUA'
local bad = {}
for _, m in ipairs(vim.fn.readfile(os.getenv("REQ_MODS"))) do
  if m ~= "" then
    local path = m:gsub("%.", "/")
    local found = #vim.api.nvim_get_runtime_file("lua/" .. path .. ".lua", false) > 0
        or #vim.api.nvim_get_runtime_file("lua/" .. path .. "/init.lua", false) > 0
    if not found then
      bad[#bad + 1] = m
    end
  end
end
vim.fn.writefile(#bad > 0 and bad or { "ALL RESOLVABLE" }, os.getenv("REQ_OUT"))
LUA

REQ_MODS="$TMP/mods.txt" REQ_OUT="$TMP/bad.txt" \
	timeout 60 nvim --headless -c "luafile $TMP/check.lua" -c 'qa!' >/dev/null 2>&1

cat "$TMP/bad.txt"
grep -q 'ALL RESOLVABLE' "$TMP/bad.txt"
