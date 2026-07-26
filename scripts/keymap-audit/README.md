# 快捷键审计工具

用运行时真实映射表（而非读代码推断）分析键位冲突。

## 用法

```sh
scripts/keymap-audit/dump.sh /tmp/maps.tsv     # 导出当前映射表
perl scripts/keymap-audit/analyze.pl /tmp/maps.tsv   # 分析前缀阻塞与命名空间占用
diff <(cut -f1-3 base.tsv) <(cut -f1-3 new.tsv)      # 改动前后回归对比
```

改键位前先导一份基线，改完再导一份 diff，确认只有预期变化。

## 为什么不能用 headless

`nvim --headless` 没有 UI，LazyVim 的 `VeryLazy` 永不触发。手动补一句
`nvim_exec_autocmds("User", { pattern = "VeryLazy" })` 看似能救，实际会把加载顺序
打乱：which-key 的 setup 跑到了 `config/keymaps.lua` 之前。

而 `which-key.add()` 只做一件事——`table.insert(M._queue, ...)`。这个队列仅在
`which-key.config.setup()` 里 flush 一次，flush 完即清空。setup 之后再调用 `add()`
的内容，没有任何代码会再去处理它，全部静默丢失。

`config/keymaps.lua` 里的映射全部经由 `util.keymap` → `wk.add()` 注册，所以在那种
测量方式下整个文件的 200 多条映射都不会出现在导出结果里——测出来的表看着正常，
实际上对这个文件全程是盲的。

`dump.sh` 因此用 `script -qec` 分配一个伪终端，让 nvim 以为自己有 UI，
`VeryLazy` 按真实顺序自然触发。

## 输出格式

制表符分隔四列：

```
G       n       <leader>ww      Window: Suitable Width      # G = 全局
B:r     n       ;dd             devtools: update document   # B:<ft> = buffer-local
```

buffer-local 部分对 `enew` 建的空 buffer 取样，只能覆盖靠 `FileType` 触发的插件。
靠真实文件路径才 attach 的（如 obsidian.nvim 需要 vault 内的文件）取不到，
那类映射要单独开真实文件验证。
