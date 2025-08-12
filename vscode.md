## Install VSCode remote development tools

### Syncing all vscode instances

We'll be installing vscode extensions into:

- (1) vscode as running on your windoze machine
- (2) vscode as running on your windows wsl
- (3) running on the remote host
- (4) running in a container running in the remote host

We want the vscode extensions to be synced across all these.  The best way is to install them into (1) and then let vscode to "propagate" them
to all the way to (4).

Open command palette at (1): `Ctrl+Shift+P` and then look fo "Settings Sync: Turn On".  You will be prompted to login to a github account.
After this everything you install in (1), will be found in (2-4) as well.

### Using VSCode with WSL linux

Don't open files directly from the WSL disk space (that way nothing works), but install the "WSL" extension and open our linux WSL disk space
form remote explorer -> WSL Targets

### Connect to REMOTEHOST

For VSCode, install "remote development extension": it has remote ssh, dev containers, etc.

open view -> command palette -> type in ssh config -> pick open ssh configuration file.

It looks like this:
```
Host SOME-NAME
  HostName YOUR-HOSTS-ADDRESS
  User YOUR-USERNAME
  # IdentityFile "\\wsl.localhost\Ubuntu\home\USERNAME\.ssh\id_rsa" 
  ## .. that wont work -> file permissions dont map too well
  ## .. so made a copy of that into:
  IdentityFile "C:\Users\USERNAME\id_rsa"
```

Now try to get a remote connection to your host.

### Connect to a CONTAINER

Once you're in the remote host's VSCode, there is a symbol of a screen in the leftmost vertical menu, called "Remote Explorer".

Click it and choose "Dev Containers" in a dropdown menu you see in the upper left part of the layout (by default it says "Remotes (Tunnels/SSH)").

Choose a container and now you are in a VSCode that runs inside the container.  You still need to install (again) all your plugins in the container VSCode.

### Interactive debugging in CONTAINER 

VSCode debugging works on the basis of a `launch.json` file.  We provide a nice one for rocm and python debugging, see it in [shared/launch.json](shared/launch.json).

If you follow the tutorial in the main readme file, that file is already in the correct place in your container.  In VSCode menus, you can choose to edit it and launch
debugging session using it.
