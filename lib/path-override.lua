-- User overrides in ~/.local/share/omk/bin go before Omarchy's own bin dir (which Omarchy's
-- default/hypr/envs.lua forces first in PATH), so a script of the same name there wins.
do
  local omk_bin = os.getenv("HOME") .. "/.local/share/omk/bin"
  local omarchy_bin = (os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/bin"
  local kept = { omk_bin, omarchy_bin }
  for entry in (os.getenv("PATH") or "/usr/local/bin:/usr/bin"):gmatch("[^:]+") do
    if entry ~= omk_bin and entry ~= omarchy_bin then table.insert(kept, entry) end
  end
  hl.env("PATH", table.concat(kept, ":"))
end
