# Remote answer-me-with-html pages: just pages <recipe>. Run `just pages` to list them.

# List recipes
[private]
default:
    @{{just_executable()}} --justfile {{justfile()}} --list pages

# Mount a host's ~/.answer-me-with-html/pages at ~/remote-<host>-pages: just pages mount mx-beelink
mount host="memryx-jacky":
    mkdir -p ~/remote-{{host}}-pages
    # Mounting again would stack a second mount on the same folder
    if mount | grep -q " on $HOME/remote-{{host}}-pages "; then echo "Already mounted"; \
    else sshfs {{host}}:.answer-me-with-html/pages ~/remote-{{host}}-pages -o volname=pages,reconnect; fi

# Unmount a host's pages: just pages umount mx-beelink
umount host="memryx-jacky":
    umount ~/remote-{{host}}-pages
