-- List of LaTeX packages officially supported/emulated by MathJax 3.x
local mathjax_supported_packages = {
  mathtools = true,
  physics = true,
  mhchem = true,
  cancel = true,
  cases = true,
  color = true,
  colortbl = true,
  empheq = true,
  extpfeil = true,
  gensymb = true,
  unicode = true,
  upgreek = true,
  amscd = true
}

-- Helper function: Safely injects raw text into the include-in-header metadata block
local function inject_header(meta, text_content, format_type)
  if not meta['include-in-header'] then
    meta['include-in-header'] = pandoc.MetaList({})
  elseif type(meta['include-in-header']) == "string" or meta['include-in-header'].t == "MetaInlines" then
    -- Upgrade single string to a MetaList if it exists as a scalar
    meta['include-in-header'] = pandoc.MetaList({ meta['include-in-header'] })
  end
  
  -- Use MetaRaw to ensure the string passes unescaped as raw HTML/LaTeX code
  local raw_node = pandoc.MetaRaw(format_type, text_content)
  table.insert(meta['include-in-header'], raw_node)
end

function Meta(meta)
  -- Fallback to 'html' if Pandoc's global FORMAT variable is uninitialized
  local format = FORMAT and FORMAT:lower() or "html"
  
  -- Attempt to read math.tex from the execution context directory
  -- Note: Adjust path to "../../math.tex" if math.tex lives two directories up like your .bib files!
  local f = io.open("math.tex", "r")
  if not f then 
    io.stderr:write("[Math Filter] WARNING: 'math.tex' file could not be found.\n")
    return meta 
  end
  local content = f:read("*all")
  f:close()

  -- Handle PDF / LaTeX target formats
  if format == "pdf" or format == "latex" then
    -- Inject the file content wholesale into the LaTeX preamble
    inject_header(meta, content, "latex")
    return meta
  end

  -- Handle HTML / HTML5 target formats
  if format == "html" or format == "html5" then
    local macros = {}
    local detected_packages = {}

    -- Process math.tex line by line
    for line in content:gmatch("[^\r\n]+") do
      -- 1. Match custom macro declarations (\newcommand or \def)
      if line:match("^%s*\\newcommand") or line:match("^%s*\\def") then
        table.insert(macros, line)
      
      -- 2. Match package declarations (\usepackage{...})
      else
        local pkg_match = line:match("^%s*\\usepackage%s*{(.-)}")
        if pkg_match then
          -- Split comma-separated package declarations, e.g., \usepackage{mathtools, physics}
          for pkg in pkg_match:gmatch("[^,%s]+") do
            if mathjax_supported_packages[pkg] then
              table.insert(detected_packages, pkg)
            end
          end
        end
      end
    end

    -- 3. Construct and inject the MathJax configuration script if supported packages exist
    if #detected_packages > 0 then
      local loader_pkgs = {}
      local tex_pkgs = {}
      for _, pkg in ipairs(detected_packages) do
        table.insert(loader_pkgs, "'[tex]/" .. pkg .. "'")
        table.insert(tex_pkgs, "'" .. pkg .. "'")
      end

      local mathjax_config = string.format([[
<script>
window.MathJax = {
  loader: {load: [%s]},
  tex: {packages: {'[+]': [%s]}}
};
</script>
]], table.concat(loader_pkgs, ", "), table.concat(tex_pkgs, ", "))

      inject_header(meta, mathjax_config, "html")
    end

    -- 4. Wrap custom macros into a hidden display math block for MathJax processing
    if #macros > 0 then
      local html_script = '<div style="display: none;">\n$$\n' 
                          .. table.concat(macros, "\n") 
                          .. '\n$$\n</div>'
      inject_header(meta, html_script, "html")
    end
  end -- <-- THIS WAS THE MISSING END TO CLOSE 'if format == "html"...'

-- Add this line right before "return meta" at the very bottom
  io.stderr:write("[Debug] Current include-in-header: " .. mw.dump(meta['include-in-header']) .. "\n")
  

  return meta
end