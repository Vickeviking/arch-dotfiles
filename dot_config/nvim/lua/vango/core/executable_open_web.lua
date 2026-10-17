local M = {}

local function html_escape(value)
	return tostring(value)
		:gsub("&", "&amp;")
		:gsub("<", "&lt;")
		:gsub(">", "&gt;")
		:gsub('"', "&quot;")
		:gsub("'", "&#39;")
end

local function mermaid_ident(value)
	return tostring(value):gsub("[^%w_]", "_")
end

local function mermaid_type(value)
	local cleaned = tostring(value):gsub('^"', ""):gsub('"$', ""):gsub("[^%w_]", "_")
	if cleaned == "" then
		return "text"
	end
	return cleaned
end

local function read_current_or_file(path)
	if vim.fn.expand("%:p") == path then
		return vim.api.nvim_buf_get_lines(0, 0, -1, false)
	end

	return vim.fn.readfile(path)
end

local function parse_dbml(lines)
	local tables = {}
	local table_order = {}
	local refs = {}
	local current_table = nil
	local in_indexes = false

	for _, raw_line in ipairs(lines) do
		local line = raw_line:gsub("//.*$", "")
		local table_name = line:match("^%s*Table%s+([%w_]+)%s*{")

		if table_name then
			current_table = table_name
			in_indexes = false
			if not tables[table_name] then
				tables[table_name] = { columns = {} }
				table.insert(table_order, table_name)
			end
		elseif current_table and line:match("^%s*Indexes%s*{") then
			in_indexes = true
		elseif current_table and line:match("^%s*}%s*$") then
			if in_indexes then
				in_indexes = false
			else
				current_table = nil
			end
		elseif current_table and not in_indexes then
			local column_name, column_type, attrs = line:match("^%s*([%w_]+)%s+([^%s%[]+)%s*(%b[])")
			if not column_name then
				column_name, column_type = line:match("^%s*([%w_]+)%s+([^%s%[]+)")
				attrs = ""
			end

			if column_name and column_name ~= "Note:" then
				local keys = {}
				if attrs:match("%f[%w]pk%f[%W]") then
					table.insert(keys, "PK")
				end
				if attrs:match("%f[%w]unique%f[%W]") then
					table.insert(keys, "UK")
				end

				local ref_table, ref_column = attrs:match("ref:%s*>%s*([%w_]+)%.([%w_]+)")
				if ref_table and ref_column then
					table.insert(keys, "FK")
					table.insert(refs, {
						from_table = current_table,
						from_column = column_name,
						to_table = ref_table,
						to_column = ref_column,
					})
				end

				table.insert(tables[current_table].columns, {
					name = column_name,
					type = column_type,
					keys = keys,
				})
			end
		end

		local from_table, from_column, to_table, to_column =
			line:match("^%s*Ref:%s*([%w_]+)%.([%w_]+)%s*>%s*([%w_]+)%.([%w_]+)")
		if from_table and from_column and to_table and to_column then
			if tables[from_table] then
				for _, column in ipairs(tables[from_table].columns) do
					if column.name == from_column and not vim.tbl_contains(column.keys, "FK") then
						table.insert(column.keys, "FK")
					end
				end
			end

			table.insert(refs, {
				from_table = from_table,
				from_column = from_column,
				to_table = to_table,
				to_column = to_column,
			})
		end
	end

	for _, ref in ipairs(refs) do
		if not tables[ref.from_table] then
			tables[ref.from_table] = { columns = {} }
			table.insert(table_order, ref.from_table)
		end
		if not tables[ref.to_table] then
			tables[ref.to_table] = { columns = {} }
			table.insert(table_order, ref.to_table)
		end
	end

	return tables, table_order, refs
end

local function dbml_to_mermaid(lines)
	local tables, table_order, refs = parse_dbml(lines)
	local output = { "erDiagram" }

	for _, table_name in ipairs(table_order) do
		table.insert(output, ("  %s {"):format(mermaid_ident(table_name)))

		local columns = tables[table_name].columns
		if #columns == 0 then
			table.insert(output, "    string external")
		else
			for _, column in ipairs(columns) do
				local key_text = ""
				if #column.keys > 0 then
					key_text = " " .. table.concat(column.keys, ",")
				end
				table.insert(output, ("    %s %s%s"):format(mermaid_type(column.type), mermaid_ident(column.name), key_text))
			end
		end

		table.insert(output, "  }")
	end

	for _, ref in ipairs(refs) do
		table.insert(
			output,
			("  %s }o--|| %s : %s"):format(
				mermaid_ident(ref.from_table),
				mermaid_ident(ref.to_table),
				mermaid_ident(ref.from_column)
			)
		)
	end

	return table.concat(output, "\n")
end

local function browser_command()
	local browsers = { "firefox", "chromium", "google-chrome", "brave-browser", "xdg-open" }

	if vim.env.BROWSER and vim.env.BROWSER ~= "" then
		table.insert(browsers, 1, vim.env.BROWSER)
	end

	for _, browser in ipairs(browsers) do
		if vim.fn.executable(browser) == 1 then
			return browser
		end
	end

	return nil
end

local function open_uri(uri)
	local browser = browser_command()
	if not browser then
		vim.notify("No browser command found", vim.log.levels.ERROR)
		return
	end

	vim.fn.jobstart({ browser, uri }, { detach = true })
end

local function preview_dir()
	local dir = vim.fn.stdpath("cache") .. "/web-preview"
	vim.fn.mkdir(dir, "p")
	return dir
end

local function preview_path(kind, path)
	local dir = preview_dir()
	local folder = vim.fn.fnamemodify(path, ":p:h")
	local basename = vim.fn.fnamemodify(folder, ":t"):gsub("[^%w_-]", "_")
	local hash = vim.fn.sha256(folder):sub(1, 12)
	return ("%s/%s-%s-%s.html"):format(dir, kind, basename, hash)
end

local function sorted_sibling_files(path, extension)
	local dir = vim.fn.fnamemodify(path, ":p:h")
	local files = vim.fn.globpath(dir, "*." .. extension, false, true)
	table.sort(files)
	return files
end

local function active_class(file, active_path)
	if file == active_path then
		return " active"
	end
	return ""
end

local function tabbed_page(title, subtitle, tabs, panels, extra_head, extra_script)
	return ([[
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s</title>
%s
<style>
:root { color-scheme: light; font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
body { margin: 0; background: #f8fafc; color: #172033; }
header { border-bottom: 1px solid #d8dee8; background: #fff; position: sticky; top: 0; z-index: 2; }
.title { padding: 16px 20px 10px; }
h1 { margin: 0; font-size: 18px; font-weight: 650; }
p { margin: 6px 0 0; color: #5b6473; font-size: 13px; }
.tabs { display: flex; gap: 4px; overflow-x: auto; padding: 0 12px 10px; }
.tab { border: 1px solid #d8dee8; background: #f8fafc; color: #334155; border-radius: 6px; padding: 8px 10px; font: inherit; font-size: 13px; white-space: nowrap; cursor: pointer; }
.tab.active { background: #172033; border-color: #172033; color: #fff; }
main { padding: 18px; }
.panel { height: 0; overflow: hidden; opacity: 0; pointer-events: none; }
.panel.active { height: auto; overflow: visible; opacity: 1; pointer-events: auto; }
.diagram { background: #fff; border: 1px solid #d8dee8; border-radius: 8px; padding: 24px; overflow: auto; }
pre.mermaid { margin: 0; min-width: max-content; }
iframe { width: 100%%; height: calc(100vh - 138px); border: 1px solid #d8dee8; border-radius: 8px; background: #fff; }
</style>
</head>
<body>
<header>
<div class="title">
<h1>%s</h1>
<p>%s</p>
</div>
<nav class="tabs">%s</nav>
</header>
<main>%s</main>
<script>
const tabs = document.querySelectorAll(".tab");
const panels = document.querySelectorAll(".panel");
tabs.forEach((tab) => {
  tab.addEventListener("click", () => {
    tabs.forEach((item) => item.classList.remove("active"));
    panels.forEach((item) => item.classList.remove("active"));
    tab.classList.add("active");
    document.getElementById(tab.dataset.panel).classList.add("active");
  });
});
%s
</script>
</body>
</html>
]]):format(
		html_escape(title),
		extra_head or "",
		html_escape(title),
		html_escape(subtitle),
		table.concat(tabs, "\n"),
		table.concat(panels, "\n"),
		extra_script or ""
	)
end

local function dbml_folder_preview_html(path)
	local files = sorted_sibling_files(path, "dbml")
	local tabs = {}
	local panels = {}

	for index, file in ipairs(files) do
		local id = "panel-" .. index
		local label = vim.fn.fnamemodify(file, ":t")
		local mermaid = dbml_to_mermaid(read_current_or_file(file))
		table.insert(
			tabs,
			('<button class="tab%s" data-panel="%s">%s</button>'):format(active_class(file, path), id, html_escape(label))
		)
		table.insert(
			panels,
			('<section id="%s" class="panel%s"><div class="diagram"><pre class="mermaid">%s</pre></div></section>'):format(
				id,
				active_class(file, path),
				html_escape(mermaid)
			)
		)
	end

	return tabbed_page(
		"EERD diagrams",
		vim.fn.fnamemodify(path, ":p:h"),
		tabs,
		panels,
		'<script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>',
		'mermaid.initialize({ startOnLoad: true, theme: "default", securityLevel: "loose" });'
	)
end

local function html_folder_preview_html(path)
	local files = sorted_sibling_files(path, "html")
	local tabs = {}
	local panels = {}

	for index, file in ipairs(files) do
		local id = "panel-" .. index
		local label = vim.fn.fnamemodify(file, ":t")
		table.insert(
			tabs,
			('<button class="tab%s" data-panel="%s">%s</button>'):format(active_class(file, path), id, html_escape(label))
		)
		table.insert(
			panels,
			('<section id="%s" class="panel%s"><iframe src="%s" title="%s"></iframe></section>'):format(
				id,
				active_class(file, path),
				html_escape(vim.uri_from_fname(file)),
				html_escape(label)
			)
		)
	end

	return tabbed_page("HTML previews", vim.fn.fnamemodify(path, ":p:h"), tabs, panels)
end

local function write_preview(kind, path, html)
	local out_path = preview_path(kind, path)
	vim.fn.writefile(vim.split(html, "\n", { plain = true }), out_path)
	open_uri(vim.uri_from_fname(out_path))
end

function M.open_current_file()
	local path = vim.fn.expand("%:p")

	if path == "" then
		vim.notify("No file to open", vim.log.levels.WARN)
		return
	end

	if vim.bo.filetype == "dbml" or path:match("%.dbml$") then
		write_preview("dbml", path, dbml_folder_preview_html(path))
		return
	end

	if vim.bo.filetype == "html" or path:match("%.html?$") then
		write_preview("html", path, html_folder_preview_html(path))
		return
	end

	open_uri(vim.uri_from_fname(path))
end

return M
