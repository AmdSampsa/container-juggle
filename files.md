## Container-Juggle files and mounts

Here we explain the shared-mount scheme and all the helper scripts.

Helper scripts are automatically on your PATH, so they just run.

**WARNING:** you don't need to worry too much about these nor the directory scheme: the underlying
scripts and framework expose the directories and load correct env variables for you in the container
so that *you* can concentrate on your work instead.

However, said all that it is also important that you know what's going on under-the-hood.

<img src="container-guy.jpg" height="300">

*Container magic!*


### A. Common directories

Directories in LOCALHOST, REMOTEHOST and shared-mounts into CONTAINER:
```bash
mirror/         # in LOCALHOST and REMOTEHOST
                # in your PATH everywhere
    context/    # context files
shared/         # in LOCALHOST, REMOTEHOST and shared mount in CONTAINER
    bin/
                # in your PATH everywhere
        contenv.bash
                # environment variable filed loaded when you enter 
                # the container

sharedump/      # in REMOTEHOST and shared mount in CONTAINER
```

### B. Directories in CONTAINER

```bash
/root/
    shared/      # see (A) - also in your CONTAINER(s) PATH
    sharedump/   # see (A)
    # OPTIONAL:
    pytorch/     # your custom compiled pytorch installation
                 # symlinks to pytorch-main, pytorch-me, etc.
    pytorch-main/ 
                # checked-out main branch
    pytorch-me/ # your personal branch
    pytorch-etc/  
                # whatever other branches

    .basrch     # loads /root/shared/bin/contenv.bash when you enter the container
```

### C. Scripts

All these scripts use the context environmental variables, so that *you* don't need to
memorize image and container names or almost anything to that matter.

Of course, they require that you have activated a context first.  If you have followed the instructions in the
main readme file & activated a context as instructed therein, then everything's OK.

The intended place to use each script is indicated with LOCALHOST, REMOTEHOST and CONTAINER.

ANYWHERE means the place doesn't matter.

### mirror/

```bash
contanalyze.bash    # REMOTEHOST / analyze containers in your REMOTEHOST
ctx.bash            # LOCALHOST, REMOTEHOST / show the current context
delctx.bash         # LOCALHOST / delete context and remote the container at REMOTESHOT
delete.bash         # REMOTEHOST / delete the container
enter.bash          # REMOTEHOST / enter the container
env.bash            # LOCALHOST / used automatically by your .bashrc
get_image_name.bash # TODO: REMOVE
getgpu.bash         # REMOTEHOST, CONTAINER / Show ROCm ASIC name
gethash.py          # TODO: REMOVE
getlink.py          # ANYWHERE / while in a git repo use this command to get a link to web UI
install.bash        # REMOTEHOST / installs stuff to your container
install_lite.bash   # TODO: REMOVE
install_private.bash 
                    # REMOTEHOST / (re)install private stuff to the container
killses.bash        # REMOTEHOST / try to kill all inactive shell sessions the container
login.bash          # LOCALHOST / login to remote host
newctx.bash         # LOCALHOST / create a new context from template
prepare.bash        # LOCALHOST / prepare the REMOTEHOST (run only once per REMOTEHOST)
pull.bash           # LOCALHOST / sync mirror, shared, etc. from REMOTEHOST - WARNING: script launches subprocesses with &
pulldir.bash        # LOCALHOST / pull a complete directory from REMOTEHOST
push.bash           # LOCALHOST / sync mirror, shared etc. to REMOTEHOST - WARNING: script launches subprocesses with &
pushdir.bash        # LOCALHOST / push a complete directory to REMOTEHOST
pushimage.bash      # REMOTEHOST / create a docker image from container & push to registry (WIP)
pushremove.bash     # LOCALHOST / sync mirror, shared, etc. to REMOTEHOST and delete files that don't exist at LOCALHOST
                    # WARNING: USE WITH CAUTION
report.bash         # LOCALHOST / reports status of all contexes at all REMOTEHOST(s)
run_all_hosts.py    # LOCALHOST / run the same command for/at all REMOTEHOST(s)
                    # NOTE: uses mirror/context/hosts.yaml - so needs to be up-to-date
runwatch.bash       # LOCALHOST / runs a watcher that keeps your file permissions consistent at REMOTEHOST
                    # NOTE: run in a separate terminal and keep always running
slct.bash           # LOCALHOST / selects a context - alias: slct
sshfs.bash          # LOCALHOST / runs a command that syncs REMOTEHOST directories to your LOCALHOST using SSHFS
                    # NOTE: run in a separate terminal and keep always running
start.bash          # REMOTEHOST / starts the container
stop.bash           # REMOTEHOST / stops the container
tmux.bash           # REMOTEHOST / start a specially named tmux session
tlogin.bash         # LOCALHOST / does an automagic tmux login into your REMOTEHOST - alias: tlg
toggle_env.bash     # REMOTEHOST / toggles your container between basic and tuned
                    # "tuned": our default container that uses shared/bin/contenv.bash
                    # for setting up env variables etc.
                    # "raw": doesn't load any extra environments
                    # you should use the "raw" container together with
                    # shared/bin/remprivate.bash 
                    # before creating an image out of container and pushing to a registry
tunnel.bash         # LOCALHOST / starts python notebook server at CONTAINER
                    # now you have python notebook at your LOCALHOST at port 9999
                    # how cool is that!
```

### shared/

```bash

bin/
    clean_torch.py      # CONTAINER
                        # compiles & installs pytorch automagically for you!
                        # detects between rocm/nvidia, architectures, etc.
                        # you need to be in a checked out pytorch directory

    contenv.bash        # CONTAINER / used by your container's .bashrc
    get_torch_main.bash
                        # CONTAINER / pull latest main into /root/pytorch-main
    get_torch_me.bash
                        # CONTAINER / pull _your_ pytorch into /root/pytorch-me
    getlink.py          # ANYWHERE / shows nice links to web UI.  Run in a git repo dir
    install_numpy1.bash
                        # CONTAINER / install numpy1 and friends
    install_triton.bash
                        # CONTAINER / checkout & install a certain triton version from git repo
    remprivate.bash     # CONTAINER / remove all private stuff (ssh keys) from your container
    setpytorch.bash     # CONTAINER / create a symlink from /root/pytorch to /root/pytorch-main
                        # or to /root/pytorch-me etc.
                        # NOTE: the container environment has /root/pytorch on its PYTHONPATH
    showenvs.bash       # CONTAINER / show torch environment

notebook/
script/
tests/
    # directories that you will use from the CONTAINER and REMOTEHOST
    # and sync between REMOTEHOST(s) and your LOCALHOST
```


