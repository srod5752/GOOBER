-- GOOBER OS startup entry point. Installed at /startup.lua by install.lua.
local program = "/goober/app/main.lua"

if not fs.exists(program) then
  term.setTextColor(colors.red)
  print("GOOBER is not installed correctly: " .. program .. " is missing.")
  term.setTextColor(colors.white)
  print("Run the GOOBER installer again to repair the program files.")
  return
end

shell.run(program)
