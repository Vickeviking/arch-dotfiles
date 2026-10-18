# nvim moves

The middle of the statusline shows the keys that matter right now: step keys while debugging, `Space Rw` on a borrow error, `K K` on a Rust symbol. `:Hints` hides them.

The handful that pays off every day. Operators combine with motions:
`d` + `w` = delete a word, `c` + `i(` = change inside parentheses.

## Moving

| Keys | Moves to |
| ---- | -------- |
| `w` / `b` / `e` | next word / back a word / end of word |
| `W` / `B` / `E` | same, but words are split by spaces only |
| `0` / `^` / `$` | line start / first non-blank / line end |
| `f x` / `t x` | onto / just before the next `x` on the line (`;` repeats, `,` reverses) |
| `gg` / `G` / `42G` | top / bottom / line 42 |
| `{` / `}` | previous / next blank line (paragraph) |
| `%` | the matching bracket |
| `C-d` / `C-u` | half a page down / up |
| `H` / `M` / `L` | top / middle / bottom of the screen |
| `zz` / `zt` / `zb` | scroll so the cursor line is centered / at the top / at the bottom |
| `C-o` / `C-i` | back / forward in the jump list (also `Space jb` / `Space jf`) |
| `gw` | Flash: type 2 letters, jump to the label |

## Operators

| Keys | Does |
| ---- | ---- |
| `d` | delete (cut) |
| `c` | change: delete, then insert |
| `y` | yank (copy) |
| `>` / `<` | indent / dedent |
| `gc` | comment toggle (`gcc` the line) |
| `=` | re-indent |
| `gU` / `gu` | upper / lower case |
| `.` | repeat the last change |
| `u` / `C-r` | undo / redo |

Double an operator to act on the whole line: `dd`, `yy`, `cc`, `>>`.

## Text objects (after an operator or in visual mode)

| Object | Means |
| ------ | ----- |
| `iw` / `aw` | inner word / a word plus its space |
| `i(` `i{` `i[` `i<` | inside the brackets |
| `a(` `a{` … | including the brackets |
| `i"` / `a"` | inside / around the quotes |
| `it` / `at` | inside / around an HTML tag |
| `ip` / `ap` | paragraph |

Examples: `ci"` change the string, `da(` delete a call's arguments with the parens,
`yi{` copy a function body, `vap` select a paragraph.

## Surround (nvim-surround)

| Keys | Does |
| ---- | ---- |
| `ys iw "` | surround a word with quotes |
| `cs " '` | change surrounding `"` to `'` |
| `ds (` | delete surrounding parentheses |
| `S )` in visual | surround the selection |

## Completion (blink) and AI (codeium)

| Keys (insert mode) | Does |
| ------------------ | ---- |
| `C-Space` | show completions (the menu stays hidden until you ask) |
| `C-j` / `C-k` | next / previous suggestion |
| `Tab` | accept the suggestion, or jump to the next snippet field |
| `C-e` | close the menu |
| `C-l` / `C-h` | scroll the documentation panel |
| `S-Tab` | accept codeium's grey ghost text (menu closed) |
| `Space wn` (normal) | switch codeium: ghost text only ↔ menu pops up while typing |

## Search and replace

| Keys | Does |
| ---- | ---- |
| `/text` `?text` | search forward / backward, `n` `N` next / previous |
| `*` / `#` | search the word under the cursor forward / backward |
| `:%s/old/new/g` | replace in the whole file (`gc` at the end to confirm each) |
| `:s/old/new/g` | replace on this line (or in the visual selection) |
| `Space nh` | clear search highlight |
| `Space fs` / `Space fc` | grep the project / grep the word under the cursor |

## Visual mode

| Keys | Does |
| ---- | ---- |
| `v` / `V` / `C-v` | characters / lines / block |
| `o` | jump to the other end of the selection |
| `gv` | reselect the last selection |
| `Alt-j` / `Alt-k` | move the selected lines down / up |
| `C-v` … `I` text `Esc` | type the same text on every line of a block |

## Windows, buffers, tabs

| Keys | Does |
| ---- | ---- |
| `Space sv` / `Space sh` | split vertically / horizontally |
| `C-h` `C-j` `C-k` `C-l` | move between splits and tmux panes (C-h also enters a hover popup) |
| `Space sm` | maximize / restore a split |
| `Space sx` | close the split |
| `Space bn` / `Space bp` | next / previous buffer |
| `Space ee` | file tree |
| `Space ff` / `Space fr` | find file / recent files |

## Opening files

| Keys / file | Does |
| ----------- | ---- |
| `Space ff` / `Space fr` | find a file / a recent file |
| `gx` | open the path or URL under the cursor in its app |
| a `.pdf` | opens in zathura, nvim goes back to your file |
| a video | opens in the default player |
| an image | shown inside nvim (kitty) |

## Marks, registers, macros

| Keys | Does |
| ---- | ---- |
| `ma` / `` `a `` | set mark `a` / jump back to it (`'a` jumps to its line) |
| `"ay` / `"ap` | yank into / paste from register `a` |
| `"+y` / `"+p` | system clipboard |
| `qa` … `q` | record a macro into `a` |
| `@a` / `@@` | play macro `a` / play the last macro again |
| `5@a` | play it five times |

## Ask, run, and the same comfort in every language

| Keys | Does |
| ---- | ---- |
| `Space Space` | **Ask** Claude (Haiku) in a float; the function under the cursor, its errors, and X-ray (when stopped) come along |
| `Space Space` in visual | ask about just the selected lines |
| `Space ae` | explain the diagnostic under the cursor, with the smallest fix |
| `:Ask question` | ask from the command line |
| in Ask | `⏎` send · `⇧⏎` new line · `Tab` to the answers · `y` yank code · `C-n` new chat · `C-c` stop · `q` hide |
| `Space cr` | **run this file**: Python, TS/JS, Go, C, C++, Java, Lua, shell (Rust: `cargo run`) · `q` closes the output |
| `Space ci` | inlay hints on/off (grey types and parameter names), any language |
| `K` | docs for the name under the cursor (Rust: `K K` opens the lens) |
| `gd` `gr` `gi` | definition, references, implementations |
| `Space ca` · `Space rn` | code actions · rename everywhere |
| `Space mp` | format now (saving formats too) |

The statusline always shows the few keys that fit where the cursor is; `:Hints` hides them.

## Command line gems

| Command | Does |
| ------- | ---- |
| `:g/pattern/d` | delete every line matching |
| `:norm A;` | run normal-mode keys on each selected line (here: append `;`) |
| `:earlier 5m` | the file as it was 5 minutes ago |
| `:Lazy` / `:Mason` | plugins / tools |
| `:checkhealth` | what's broken and why |
| `:help topic` | the manual, `C-]` follows a link |
