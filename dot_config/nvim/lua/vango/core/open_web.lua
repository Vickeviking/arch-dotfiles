local M = {}

local function html_escape(value)
	return tostring(value):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"):gsub("'", "&#39;")
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
				table.insert(
					output,
					("    %s %s%s"):format(mermaid_type(column.type), mermaid_ident(column.name), key_text)
				)
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

local function sorted_sibling_files_any(path, extensions)
	local dir = vim.fn.fnamemodify(path, ":p:h")
	local seen = {}
	local files = {}

	for _, extension in ipairs(extensions) do
		for _, file in ipairs(vim.fn.globpath(dir, "*." .. extension, false, true)) do
			if not seen[file] then
				seen[file] = true
				table.insert(files, file)
			end
		end
	end

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
.diagram { position: relative; height: calc(100vh - 154px); background: #fff; border: 1px solid #d8dee8; border-radius: 8px; overflow: hidden; touch-action: none; }
.diagram-canvas { min-width: max-content; width: fit-content; padding: 24px; transform-origin: 0 0; cursor: grab; user-select: none; }
.diagram-canvas.is-panning { cursor: grabbing; }
.diagram-toolbar { position: absolute; top: 12px; right: 12px; z-index: 1; display: flex; gap: 4px; padding: 4px; background: rgba(255, 255, 255, 0.92); border: 1px solid #d8dee8; border-radius: 6px; box-shadow: 0 6px 18px rgba(15, 23, 42, 0.10); }
.diagram-button { min-width: 32px; height: 32px; border: 1px solid #cbd5e1; border-radius: 5px; background: #fff; color: #172033; font: inherit; font-size: 13px; cursor: pointer; }
.diagram-button:hover { background: #f1f5f9; }
.diagram-reset { min-width: 58px; padding: 0 8px; }
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
			('<button class="tab%s" data-panel="%s">%s</button>'):format(
				active_class(file, path),
				id,
				html_escape(label)
			)
		)
		table.insert(
			panels,
			('<section id="%s" class="panel%s"><div class="diagram"><div class="diagram-toolbar" aria-label="Diagram zoom"><button class="diagram-button" type="button" data-action="zoom-out" title="Zoom out">-</button><button class="diagram-button diagram-reset" type="button" data-action="reset" title="Reset zoom">100%%</button><button class="diagram-button" type="button" data-action="zoom-in" title="Zoom in">+</button></div><div class="diagram-canvas" title="Drag to pan. Double-click a table area to zoom in."><pre class="mermaid">%s</pre></div></div></section>'):format(
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
		[[
mermaid.initialize({ startOnLoad: false, theme: "default", securityLevel: "loose" });

function setupDiagramZoom() {
  const diagrams = document.querySelectorAll(".diagram");

  diagrams.forEach((diagram) => {
    const canvas = diagram.querySelector(".diagram-canvas");
    const scaleLabel = diagram.querySelector("[data-action='reset']");
    let scale = 1;
    let originX = 0;
    let originY = 0;
    let isPanning = false;
    let startX = 0;
    let startY = 0;
    let startOriginX = 0;
    let startOriginY = 0;

    const clamp = (value) => Math.min(24, Math.max(0.2, value));
    const render = () => {
      canvas.style.transform = `translate(${originX}px, ${originY}px) scale(${scale})`;
      scaleLabel.textContent = `${Math.round(scale * 100)}%`;
    };
    const zoomAt = (nextScale, clientX, clientY) => {
      const rect = diagram.getBoundingClientRect();
      const previousScale = scale;
      scale = clamp(nextScale);
      const factor = scale / previousScale;
      const localX = clientX - rect.left - originX;
      const localY = clientY - rect.top - originY;

      originX -= localX * (factor - 1);
      originY -= localY * (factor - 1);
      render();
    };
    const center = () => {
      const rect = diagram.getBoundingClientRect();
      return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
    };

    diagram.querySelector("[data-action='zoom-out']").addEventListener("click", () => {
      const point = center();
      zoomAt(scale / 1.5, point.x, point.y);
    });
    diagram.querySelector("[data-action='zoom-in']").addEventListener("click", () => {
      const point = center();
      zoomAt(scale * 1.5, point.x, point.y);
    });
    scaleLabel.addEventListener("click", () => {
      scale = 1;
      originX = 0;
      originY = 0;
      render();
    });

    diagram.addEventListener("wheel", (event) => {
      if (!event.ctrlKey && !event.metaKey) {
        return;
      }

      event.preventDefault();
      zoomAt(scale * (event.deltaY < 0 ? 1.25 : 0.8), event.clientX, event.clientY);
    }, { passive: false });

    diagram.addEventListener("dblclick", (event) => {
      if (event.target.closest(".diagram-toolbar")) {
        return;
      }

      zoomAt(scale * 2, event.clientX, event.clientY);
    });

    diagram.addEventListener("pointerdown", (event) => {
      if (event.button !== 0 || event.target.closest(".diagram-toolbar")) {
        return;
      }

      isPanning = true;
      startX = event.clientX;
      startY = event.clientY;
      startOriginX = originX;
      startOriginY = originY;
      canvas.classList.add("is-panning");
      diagram.setPointerCapture(event.pointerId);
    });
    diagram.addEventListener("pointermove", (event) => {
      if (!isPanning) {
        return;
      }

      originX = startOriginX + event.clientX - startX;
      originY = startOriginY + event.clientY - startY;
      render();
    });
    diagram.addEventListener("pointerup", () => {
      isPanning = false;
      canvas.classList.remove("is-panning");
    });
    diagram.addEventListener("pointercancel", () => {
      isPanning = false;
      canvas.classList.remove("is-panning");
    });

    render();
  });
}

mermaid.run().then(setupDiagramZoom);
]]
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
			('<button class="tab%s" data-panel="%s">%s</button>'):format(
				active_class(file, path),
				id,
				html_escape(label)
			)
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

local function markdown_fallback_html(lines)
	local html = {}
	local in_code = false
	local paragraph = {}

	local function flush_paragraph()
		if #paragraph > 0 then
			table.insert(html, "<p>" .. html_escape(table.concat(paragraph, " ")) .. "</p>")
			paragraph = {}
		end
	end

	for _, line in ipairs(lines) do
		if line:match("^%s*```") then
			flush_paragraph()
			if in_code then
				table.insert(html, "</code></pre>")
			else
				table.insert(html, "<pre><code>")
			end
			in_code = not in_code
		elseif in_code then
			table.insert(html, html_escape(line))
		else
			local heading, text = line:match("^(#+)%s+(.+)$")
			if heading then
				flush_paragraph()
				local level = math.min(#heading, 6)
				table.insert(html, ("<h%d>%s</h%d>"):format(level, html_escape(text), level))
			elseif line:match("^%s*$") then
				flush_paragraph()
			else
				table.insert(paragraph, line)
			end
		end
	end

	flush_paragraph()
	if in_code then
		table.insert(html, "</code></pre>")
	end

	return table.concat(html, "\n")
end

local function markdown_to_html(lines)
	if vim.fn.executable("pandoc") == 1 then
		local input = table.concat(lines, "\n")
		local output = vim.fn.system({ "pandoc", "--from", "gfm", "--to", "html", "--wrap=none" }, input)

		if vim.v.shell_error == 0 then
			return output
		end
	end

	return markdown_fallback_html(lines)
end

local function markdown_folder_preview_html(path)
	local files = sorted_sibling_files_any(path, { "md", "markdown" })
	local tabs = {}
	local panels = {}

	for index, file in ipairs(files) do
		local id = "panel-" .. index
		local label = vim.fn.fnamemodify(file, ":t")
		table.insert(
			tabs,
			('<button class="tab%s" data-panel="%s">%s</button>'):format(
				active_class(file, path),
				id,
				html_escape(label)
			)
		)
		table.insert(
			panels,
			('<section id="%s" class="panel%s"><article class="markdown-body">%s</article></section>'):format(
				id,
				active_class(file, path),
				markdown_to_html(read_current_or_file(file))
			)
		)
	end

	return tabbed_page(
		"Markdown previews",
		vim.fn.fnamemodify(path, ":p:h"),
		tabs,
		panels,
		[[
<style>
.markdown-body {
	box-sizing: border-box;
	max-width: 860px;
	margin: 0 auto;
	padding: 32px 40px;
	background: #fff;
	border: 1px solid #d8dee8;
	border-radius: 8px;
	color: #172033;
	line-height: 1.65;
}
.markdown-body h1,
.markdown-body h2,
.markdown-body h3,
.markdown-body h4 {
	line-height: 1.25;
	margin: 1.45em 0 0.55em;
	color: #101828;
}
.markdown-body h1:first-child,
.markdown-body h2:first-child,
.markdown-body h3:first-child {
	margin-top: 0;
}
.markdown-body h1 { font-size: 2rem; border-bottom: 1px solid #e2e8f0; padding-bottom: 0.35em; }
.markdown-body h2 { font-size: 1.45rem; border-bottom: 1px solid #e2e8f0; padding-bottom: 0.25em; }
.markdown-body h3 { font-size: 1.15rem; }
.markdown-body p,
.markdown-body ul,
.markdown-body ol,
.markdown-body blockquote,
.markdown-body pre,
.markdown-body table { margin: 0 0 1em; }
.markdown-body a { color: #0f766e; text-decoration-thickness: 0.08em; text-underline-offset: 0.16em; }
.markdown-body blockquote {
	padding: 0.1em 1em;
	color: #475569;
	border-left: 4px solid #cbd5e1;
	background: #f8fafc;
}
.markdown-body code {
	padding: 0.15em 0.35em;
	border-radius: 4px;
	background: #edf2f7;
	font-family: ui-monospace, SFMono-Regular, "SF Mono", Consolas, "Liberation Mono", monospace;
	font-size: 0.92em;
}
.markdown-body pre {
	overflow: auto;
	padding: 16px;
	border-radius: 8px;
	background: #111827;
	color: #e5e7eb;
}
.markdown-body pre code {
	padding: 0;
	background: transparent;
	color: inherit;
}
.markdown-body table {
	width: 100%;
	border-collapse: collapse;
	display: block;
	overflow-x: auto;
}
.markdown-body th,
.markdown-body td {
	border: 1px solid #d8dee8;
	padding: 8px 10px;
}
.markdown-body th { background: #f1f5f9; text-align: left; }
@media (max-width: 720px) {
	main { padding: 10px; }
	.markdown-body { padding: 22px 18px; }
}
</style>
]],
		nil
	)
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

	if vim.bo.filetype == "markdown" or path:match("%.md$") or path:match("%.markdown$") then
		write_preview("markdown", path, markdown_folder_preview_html(path))
		return
	end

	open_uri(vim.uri_from_fname(path))
end

return M
