# Container-Juggle

This is Container-Juggle - your framework for doing development with lots of remote hosts and containers in a GPU environment.
Special emphasis is on pytorch development.

Why use it?

Container Juggle eliminates the grunt work:

- Book-keeping of your hosts and containers - no mindload in remembering those hosts, image and container names
- Setting environmental variables: paths etc. in your container
- Docker shared directories - loading env variables and python tools from therein
- Probing the ROCm / NV architecture and setting correct flags for compilation
- Persistent terminal connections with tmux
- Python notebook server from the running container to your local laptop web UI
- Watchers that keep your file permissions right for docker shared mounts
- And more

<img src="juggler.jpg" height="300">

*Container-Juggle makes working with containers fun!*

Please follow this tutorial step-by-step to get Container-Juggle up and working.

There is also a [faq](faq.md)

## A. Nomenclature

LOCALHOST = your laptop

REMOTEHOST = remote server where you ssh to

CONTAINER = container running at REMOTEHOST

## B. Initial setup

### 1. Prepare your LOCALHOST

*do this just once*

#### a. Arrange the directories

This repo has the structure
```bash
$HOME/ # your linux homedir in windows WSL
    container-juggle/
        mirror/
        shared/
```
However, the framework and scripts expect you to have them in
```bash
$HOME/ # your linux homedir in windows WSL
    mirror/
    shared/
```
Sorry for the inconvenience, but you have to `cp -r` directories `mirror/` and `shared/` into your `$HOME` directory.

#### b. Install some packages

```bash
sudo apt-get update && sudo apt-get install -y inotify-tools emacs dialog tmux silversearcher-ag iputils-ping python3-pip python3-paramiko
```

#### c. Create custom ssh keys

Create a custom ssh keypair.  This is used for your remote host(s) authentication into github, both from REMOTEHOST and from withint CONTAINER
```bash
mkdir -p custom_ssh_keys && ssh-keygen -t rsa -b 4096 -f ~/custom_ssh_keys/id_rsa
```
(just press enter few times for no passphrase).  Copy-paste `custom_ssh_keys/id_rsa.pub` into your github account, using github's web UI.  After adding the key, remember to click the
"configure SSO" dropdown menu in web UI and therein authorize your workspace, etc.

#### d. bashrc

Do this:
```bash
echo "source mirror/env.bash" >> $HOME/.bashrc
```
it adds a line into your `~/.bashrc`.  Tadaa - now you can access all executables from `~/mirror` and `~/shared`.

In order for that to take effect, you now need to restart your WSL terminal(s)

#### e. context template

A **"context"** is a set of parameters, defining a **remote host + docker image name + container name**, i.e. it uniquely defines your working environment.

Let's create a personalized template for just that with your username, etc:
```bash
cp ~/mirror/context/ctx_scaffold.bash ~/mirror/context/my_scaffold.bash
```
After that, edit your personalized `my_scaffold.bash` and fill in these fields:
```bash
# ...
export username=
# ...
export gituser=
export gitname=
export gitemail=
export GH_TOKEN= ## github token for gh tools easy access
export DOCKER_USER= ## docker credentials for pushing stuff to a registry
export DOCKER_PASS= ##
export DOCKER_REG= ## docker registry
```
Needless to say, don't spread these around.

#### f. host records

It is a good idea to keep a track of all your hosts and their specs, so do this:
```bash
cp ~/mirror/context/hosts_template.yaml ~/mirror/context/hosts.yaml
```
there are also some scripts that use `hosts.yaml`.

*A tip: once you have a hosts.yaml, share it among your team*

### 2. Setup your first context

*You will be creating lots of these.  Your contexts will be piling up in ~/mirror/context.*

Let's define your first container, its image id, name and where it's going to run.

Start at LOCALHOST with 
```bash
newctx.bash funkyzeit
```

Next, look for the newly created `funkyzeit.bash` in `~/mirror/context` and edit it and fill in the details:
```bash
#!/bin/bash
export contextname= ## this should have exactly the same name as the script, i.e. "funkyzeit" (without .bash extension)
# ...
export container_name=  ## the name you'll be giving to the running container ## TIP: add your username to the container name for easier identification
export image_id= ## name of the docker image
export hostname= ## name of your remote host
export hostnick= ## host nickname same that you use in hosts.yaml
export sshport=22 ## port for ssh connections
# ...
```

### 3. Activate a context

Fire up the context menu at LOCALHOST with
```bash
slct
```
and choose `funkyzeit.bash` from the list.

Now your terminal session has all the env variables activated and our shorthand commands
know where to connect and which image and container to use.

When you have lots of containers, it's easy to juggle between them: just fire up `slct` at your LOCALHOST.

### 4. Prepare a remote host

*NOTE: you need to do this only once per host*

You need to have done step (3) before this.

We assume that you are familiar in creating ssh keys, copying them to a new ssh host and setting up automagic login.  So you need to do that basic stuff first: setup passwordless login to the remote host (google is your friend).

Once you have done all that basic jazz, run from LOCALHOST (*not* at REMOTEHOST):
```bash
prepare.bash
```
It will install remotely lot of stuff into your REMOTEHOST and set it up.

Sync bash scripts, tools etc. by running at LOCALHOST:
```bash
push.bash
```
That is a short-hand command you should keep in mind and use it always when syncing from LOCALHOST to REMOTEHOST.

### 5. Prepare a new container

Log into your REMOTEHOST with
```bash
login.bash
```
NOTE: it's very important to use that helper script instead of the plain ssh command.

Start a tmux session with
```bash
tmux.bash
```
(emphasis on that `.bash`)

Now we have a persistent tmux session that never dies even if the ip connection goes sour.

Next, let's continue by starting the container at REMOTEHOST:
```bash
start.bash
```
After that, prepare the container and install it with some tools, ssh keys and whatnots by running at REMOTEHOST:
```bash
install.bash
```
Or if you want a one-liner for that:
```bash
start.bash && install.bash
```
Now you have automagically pulled the the image and started a container that will run in the background *para siempre*.

### 6. Enter the container

Get into the container at REMOTEHOST with:
```bash
enter.bash
```
You can now probe your pytorch installation in CONTAINER by:
```bash
showenvs.bash
```

## C. Workflow

So now your workflow looks like this:

Suppose you had those tmux sessions running in your containers and the ip-connection / vpn was cut, do this at LOCALHOST:

- Open your WSL terminal
- Run `slct` -> select your context
- Give the shorthand command `tlg`

and *tadaa* - you are inside the container, exactly where you left last time.

If you have several session in a container, the shorthand command `tlg` will always choose the next one it found hanging there and will use it - otherwise it will give an error message.

Fallback: if that doesn't work for some reason, you need to give these commands:
```bash
slct
login.bash
tmux ls # see all tmux session 
tmux attach # attach to the old session
```

If you want to start a new session inside the container, just do at LOCALHOST:
```bash
slct # if not in the context already
login.bash
tmux.bash
enter.bash
```
Feel free to have as many sessions as your heart desires.

Sometimes you might want to see more exactly how many tmux sessions, etc. you have, so do (start at LOCALHOST):
```bash
slct # if not in the context already
login.bash
tmux ls # lists all tmux session, NOTE: without .bash, i.e. original tmux command
tmux kill-server # kills all tmux sessions in the host
```

Additional tips:

- **Use VSCode for all your connections to the remote hosts and containers!**  You have instructions on how to do that in [vscode.md](vscode.md).
- When opening a WSL terminal, open various tabs - in each tab you can keep a different context at your disposal.
- Shorthand alias `slast` is faster than using `slct` - it picks up the last acticated context.

Next I recommend that you take a look at [files.md](files.md) to see the scripts, environmental files and their installation scheme.

## D. Syncing

Typically you work with multiple contexes (i.e. remotehosts and containers) simultaneously - each one of them in a different tab as I suggested above.

It is very easy to sync between them, just use use `push.bash` and `pull.bash` at LOCALHOST.  

However, **avoid** this:
```bash
pull.bash && push.bash # WARNING WARNING DON'T DO THIS
```
As both `pull.bash` and `push.bash` launch several subprocesses with `&` and they exit before all those
rsync processes are ready.

## E. Python notebook from the container

At LOCALHOST run:
```bash
slct # if not in the context already
tunnel.bash
```
keep it alive and open your browser at http://localhost:9999.

## F. File watcher

Tired of those filesystem permission problems when using docker shared mounts?  Try this:

At LOCALHOST run:
```bash
slct # if not in the context already
runwatch.bash
```

## G. Compiling pytorch from scratch

At CONTAINER run:
```bash
get_torch_main.bash
cd ~/pytorch-main
clean_torch.bash --yes
```
That detects ROCm vs NVidia automatically and picks up the correct single architecture for compilation.

After it's ready, use
```bash
setpytorch.bash main # makes symlink from ~/pytorch -> ~/pytorch-main and checks triton compatibility
```

## H. Cleanup file sync

Suppose you have your `hosts.yaml` (see above) up-to-date, at LOCALHOST run:
```bash
run_all_hosts.py pushremove.bash
```
It will sync to all your hosts and remove in them all the files that are not present at LOCALHOST.

## I. Check the status of all your contexes

At LOCALHOST:
```bash
report.bash
```

## J. Save container to a registry

At REMOTEHOST:
```bash
toggle_env.bash
```
That removes the loading of custom env variables when you enter the CONTAINER.
Then after entering the CONTAINER again, do:
```bash
remprivate.bash
```
which removes all your personal stuff (ssh keys) from the container.

Next you'd might want to test that your CONTAINER still works as intended.

Finally, do at REMOTEHOST:
```bash
pushimage.bash your-image-name
```


## Author

(C) Copyright 2025 Sampsa Riikonen

`sampsa.riikonen _at_ amd.com`

## License

The Unlicense
