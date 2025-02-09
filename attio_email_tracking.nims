
switch("d", "ssl")
switch("mm", "orc")
switch("threads", "on")
let dirs = listDirs(thisDir() & "/nimbledeps/pkgs2/")
for dir in dirs:
  switch("path", dir)
switch("nimblePath", "nimbledeps/pkgs2")