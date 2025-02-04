# FAQ

### 1. Container-Juggle shorthand commands don't work

Q: I used `slct` to load a context, did `login.bash` but in the remote host, the shorthand commands `start.bash` etc. don't work.

A: When using a new host for the first time, you need to (1) select context with `slct` and run `prepare.bash` (only once for each new host).
