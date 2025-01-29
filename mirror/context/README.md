A "context" is a combination of:

- a remote host
- an image
- a container if that image

To create a context:

- copy ctx_scaffold.bash to your-context.bash (or use newctx.bash)
- fill in the details

Always when you log in, you must source a context before anything else, i.e.
```bash
source mirror/context/your-context.bash
```
or better: use the slct alias

IMPORTANT: the filename and contextname within the bash file must match exactly
