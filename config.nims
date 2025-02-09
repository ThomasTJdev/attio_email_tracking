
switch("d", "ssl")
switch("mm", "orc")
switch("threads", "on")
switch("nimblePath", "nimbledeps/pkgs2")
let dirs = listDirs(thisDir() & "/nimbledeps/pkgs2/")
for dir in dirs:
  switch("path", dir)