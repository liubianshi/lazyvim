# 快捷键审计工具

用运行时真实映射表（而非读代码推断）分析键位冲突。

## 用法

```sh
scripts/keymap-audit/dump.sh /tmp/maps.tsv     # 导出当前映射表
perl scripts/keymap-audit/analyze.pl /tmp/maps.tsv   # 分析前缀阻塞与命名空间占用
diff <(cut -f1-3 base.tsv) <(cut -f1-3 new.tsv)      # 改动前后回归对比
```

改键位前先导一份基线，改完再导一份 diff，确认只有预期变化。

## 为什么用伪终端而不是 headless

`nvim --headless` 没有 UI，LazyVim 的 `VeryLazy` 永不触发，而 `config/keymaps.lua`
正是挂在 `VeryLazy` 上加载的。裸跑 headless 时这个文件根本不执行，200 多条映射
连同 `:Gtags*` 一类用户命令全部缺席——导出的表看着正常，实际上对这个文件全程是盲的。

手动补一句 `nvim_exec_autocmds("User", { pattern = "VeryLazy" })` 能把文件拉起来，
效果比想象的好：实测全局 normal 映射 549 条，对伪终端的 551 条只差 `[i` / `]i`
两条 snacks scope 跳转。但差多少要靠每次实测才知道，改动一多就得反复论证「这次
的缺口是否落在关心的范围内」。

`dump.sh` 因此用 `script -qec` 分配一个伪终端，让 nvim 以为自己有 UI，`VeryLazy`
按真实顺序自然触发，省掉那层论证。

## 输出格式

制表符分隔四列：

```
G       n       <leader>ww      Window: Suitable Width      # G = 全局
B:r     n       ;dd             devtools: update document   # B:<ft> = buffer-local
```

buffer-local 部分对 `enew` 建的空 buffer 取样，只能覆盖靠 `FileType` 触发的插件。
靠真实文件路径才 attach 的（如 obsidian.nvim 需要 vault 内的文件）取不到，
那类映射要单独开真实文件验证。
