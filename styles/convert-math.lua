-- math-filter.lua

local function ensure_meta_list(meta, key)
  if not meta[key] then
    meta[key] = pandoc.MetaList({})
  elseif meta[key].t ~= "MetaList" then
    meta[key] = pandoc.MetaList({ meta[key] })
  end
end

local function inject_header_html(meta, text_content)
  ensure_meta_list(meta, "header-includes")
  table.insert(meta["header-includes"], pandoc.RawBlock("html", text_content))
end

local function inject_header_latex(meta, text_content)
  ensure_meta_list(meta, "header-includes")
  table.insert(meta["header-includes"], pandoc.RawBlock("latex", text_content))
end

local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*all")
  f:close()
  return content
end

local function js_escape(s)
  return s:gsub("\\", "\\\\"):gsub('"', '\\"')
end

local function parse_macros(content)
  local items = {}

  for line in content:gmatch("[^\r\n]+") do
    -- remove comments
    line = line:gsub("%%.*$", "")

    -- \newcommand{\rss}{\mathrm{RSS}}
    local name, body =
      line:match("^%s*\\newcommand%s*{%s*\\([A-Za-z]+)%s*}%s*{(.*)}%s*$")

    if name and body then
      table.insert(items, string.format(
        '      %s: "%s"',
        name,
        js_escape(body)
      ))
    else
      -- \newcommand{\dl}[1]{{\hspace{#1mu}\mathrm d}}
      local name2, nargs, body2 =
        line:match("^%s*\\newcommand%s*{%s*\\([A-Za-z]+)%s*}%s*%[(%d+)%]%s*{(.*)}%s*$")

      if name2 and nargs and body2 then
        table.insert(items, string.format(
          '      %s: ["%s", %s]',
          name2,
          js_escape(body2),
          nargs
        ))
      end
    end
  end

  return table.concat(items, ",\n")
end

function Meta(meta)
  local format = FORMAT and FORMAT:lower() or ""

  local root = "."
  if meta["project-root"] then
    root = pandoc.utils.stringify(meta["project-root"])
  end

  local math_path = root .. "/math.tex"
  local content = read_file(math_path)

  if not content then
    io.stderr:write("[Math Filter] WARNING: math.tex not found at: " .. math_path .. "\n")
    return meta
  end

  io.stderr:write("[Math Filter] found math.tex at: " .. math_path .. "\n")

  if format:match("latex") or format:match("pdf") then
    inject_header_latex(meta, content)
    return meta
  end

  if format:match("html") then
    local macros_js = parse_macros(content)

    local mathjax_config = [[
<script>
window.MathJax = {
  loader: {
    load: [
      '[tex]/physics',
      '[tex]/mathtools'
    ]
  },
  tex: {
    packages: {
      '[+]': [
        'physics',
        'mathtools'
      ]
    },
    macros: {
]] .. macros_js .. [[
    }
  }
};
</script>
]]

    inject_header_html(meta, mathjax_config)
  end

  return meta
end