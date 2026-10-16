// Surfingkeys mappings mirroring Viktor's nvim keymaps (~/.config/nvim/lua/vango/core/keymaps.lua).
// Leader = Space, like nvim. Edit this file; `desk-theme <name>` rebuilds
// ~/.config/themes/current/surfingkeys.js (this file + the palette's colors).
// Surfingkeys defaults still work: hjkl scroll, f hints, / find, o open, x close tab, ...

const L = '<Space>';

// --- insert mode: jk exits, like nvim -------------------------------------
api.imap('jk', '<Esc>');

// --- tabs: <leader>t* (nvim tabs) and <leader>b* (nvim buffers) ------------
api.map(L + 'tt', 'on');          // new tab                       (<leader>tt tabnew)
api.map(L + 'tx', 'x');           // close tab                     (<leader>tx tabclose)
api.map(L + 'tk', 'R');           // next tab                      (<leader>tk tabn)
api.map(L + 'tj', 'E');           // previous tab                  (<leader>tj tabp)
api.map(L + 'tb', 'yt');          // duplicate tab                 (<leader>tb tabnew %)
api.map(L + 'bl', 'T');           // pick a tab from a list        (<leader>bl ls)
api.map(L + 'bn', 'R');           // next tab                      (<leader>bn bnext)
api.map(L + 'bp', 'E');           // previous tab                  (<leader>bp bprevious)
api.map(L + 'bd', 'x');           // close tab                     (<leader>bd bdelete)

// --- jumps: <leader>jb / <leader>jf = history back / forward ---------------
api.map(L + 'jb', 'S');           // back                          (<leader>jb C-o)
api.map(L + 'jf', 'D');           // forward                       (<leader>jf C-i)

// --- finding: <leader>f* like telescope ------------------------------------
api.map(L + 'ff', 'T');           // fuzzy-find open tabs          (<leader>ff find_files)
api.map(L + 'fr', 'oh');          // recent: history               (<leader>fr oldfiles)
api.map(L + 'fs', '/');           // find string on the page       (<leader>fs live_grep)
api.map(L + 'fc', 'sg');          // search the selection/word     (<leader>fc grep_string)
api.map(L + 'nh', '<Esc>');       // clear search highlights       (<leader>nh nohl)

// --- explorer: <leader>e* = bookmarks --------------------------------------
api.map(L + 'ee', 'ob');          // open a bookmark               (<leader>ee NvimTreeToggle)

// --- jumping to links like flash.nvim's `s` and gd -------------------------
api.map('s', 'f');                // label-jump to a link          (flash `s`)
api.map('gd', 'f');               // "go to definition" = follow a link

// --- splits: <leader>sv opens the current page in a new window ------------
api.map(L + 'sv', 'yt');          // closest browser analogue of a split
api.map(L + 'sx', 'x');           // close it again                (<leader>sx close)
