# FAQ

### 1. Container-Juggle shorthand commands don't work

Q: I used `slct` to load a context, did `login.bash` but in the remote host, the shorthand commands `start.bash` etc. don't work.

A: When using a new REMOTEHOST for the first time, you need to (1) select context with `slct` and run `prepare.bash` from LOCALHOST.  Do this procedure only once for each new REMOTEHOST.

### 2. VSCode to REMOTEHOST and CONTAINER doesn't connect

Q: VSCode says it can't SSH to the REMOTEHOST

A: Your REMOTEHOST has probably run out of diskspace.   Make a terminal connection and clean up some.

### 3. No such file or directory when using login.bash

Q: I did `login.bash` as instructed, but got `cat: ... .bash: No such file or directory`.

A: You didn't send the new context files into the REMOTEHOST using `push.bash`.  Please revisit the step-by-step instructions.

### 4. Establishing VSCode connection into the container takes ages

Q: I am opening a VSCode connection to a container as explained in [vscode.md](vscode.md), but its taking a lot of time

A: It can take some time when doing that for the first time (as it install vscode server into the container).  After that you should save that session as a vscode workspace file.  You can save the workspace file into your LOCALHOST (when saving the workspace file there is a button "show local") -> now you have a vscode workspace file at LOCALHOST that defines the session in CONTAINER.  When opening that workspace file it opens very quickly.

