#!/bin/sh
# 导出运行时真实映射表。用法: scripts/keymap-audit/dump.sh <输出路径>
#
# 必须走伪终端(script -qec)，理由见 dump-maps.lua 顶部注释：
# headless 下手动触发 VeryLazy 会打乱加载顺序，令 config/keymaps.lua 的
# 全部映射静默丢失，导出结果对该文件完全是盲的。
set -e
out="${1:?用法: dump.sh <输出路径>}"
dir="$(cd "$(dirname "$0")" && pwd)"
cd "$dir/../.."
MAPDUMP="$out" script -qec \
  "nvim -c 'autocmd User VeryLazy ++once lua vim.defer_fn(function() vim.cmd([[luafile $dir/dump-maps.lua]]) end, 4000)'" \
  /dev/null >/dev/null 2>&1
wc -l < "$out"
