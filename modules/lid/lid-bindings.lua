-- Lid close follows omk-lid's sleep/awake mode (a Touch Bar strip's lid-mode hold flips it).
hl.unbind("switch:on:Lid Switch")
hl.unbind("switch:off:Lid Switch")
o.bind("switch:on:Lid Switch", nil, os.getenv("HOME") .. "/.local/bin/omk-lid close", { locked = true })
o.bind("switch:off:Lid Switch", nil, os.getenv("HOME") .. "/.local/bin/omk-lid open", { locked = true })
