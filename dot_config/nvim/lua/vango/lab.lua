-- Lockscope from nvim (Space ds): pick a labsync recording in this project's
-- target/lab/ (newest first) and open it with lab-view in the browser.
-- Recordings come from programs using the labsync crate (genomlysning/crates/labsync).

local M = {}

local function root()
  local found = vim.fs.find("Cargo.toml", { upward = true, path = vim.fn.expand("%:p:h") })[1]
  return found and vim.fs.dirname(found) or vim.fn.getcwd()
end

function M.open()
  if vim.fn.executable("lab-view") == 0 then
    vim.notify("Lockscope: lab-view isn't installed (cargo install --path ~/dev/project/genomlysning/crates/lab-view)", vim.log.levels.WARN)
    return
  end
  -- target/lab of this crate, or of the workspace above it
  local files = {}
  local dir = root()
  for _ = 1, 3 do
    files = vim.fn.glob(dir .. "/target/lab/*.json", false, true)
    if #files > 0 then
      break
    end
    dir = vim.fs.dirname(dir)
  end
  if #files == 0 then
    vim.notify("Lockscope: no recordings in target/lab yet; run a program that calls labsync::record or labsync::explore", vim.log.levels.INFO)
    return
  end
  table.sort(files, function(a, b)
    return vim.fn.getftime(a) > vim.fn.getftime(b)
  end)
  local function show(f)
    vim.system({ "lab-view", f }, { text = true }, function(r)
      if r.code ~= 0 then
        vim.schedule(function()
          vim.notify("lab-view: " .. (r.stderr or ""), vim.log.levels.ERROR)
        end)
      end
    end)
  end
  if #files == 1 then
    return show(files[1])
  end
  vim.ui.select(files, {
    prompt = "Lockscope recording",
    format_item = function(f)
      local name = vim.fn.fnamemodify(f, ":t:r")
      local age = os.time() - vim.fn.getftime(f)
      local when = age < 120 and "just now" or age < 3600 and (math.floor(age / 60) .. " min ago") or os.date("%d %b %H:%M", vim.fn.getftime(f))
      return (name:match("%-failure$") and "✗ " or "  ") .. name .. "  · " .. when
    end,
  }, function(f)
    if f then
      show(f)
    end
  end)
end

-- Structure movie (Space dM): every stop of the debug session so far, animated:
-- lists and trees laid out as lists and trees (xray-movie, genomlysning).
function M.movie()
  if vim.fn.executable("xray-movie") == 0 then
    vim.notify("xray-movie isn't installed (cargo install --path ~/dev/project/genomlysning/crates/xray-movie)", vim.log.levels.WARN)
    return
  end
  vim.system({ "xray-movie" }, { text = true }, function(r)
    vim.schedule(function()
      if r.code ~= 0 then
        vim.notify((r.stderr or ""):gsub("^xray%-movie: ", "Structure movie: "), vim.log.levels.INFO)
      end
    end)
  end)
end

return M
