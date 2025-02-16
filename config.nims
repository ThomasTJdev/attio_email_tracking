
switch("d", "ssl")
switch("mm", "orc")
switch("threads", "on")

when NimMajor >= 2:
  switch("nimblePath", "nimbledeps/pkgs2")

  # begin Nimble config (version 2)
  let dirs = listDirs(thisDir() & "/nimbledeps/pkgs2/")
  for dir in dirs:
    switch("path", dir)
  # end Nimble config

else:
  switch("nimblePath", "nimbledeps/pkgs")

  # begin Nimble config (version 2)
  let dirs = listDirs(thisDir() & "/nimbledeps/pkgs/")
  for dir in dirs:
    switch("path", dir)
  # end Nimble config