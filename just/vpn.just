# Office VPN on the jump host: just vpn <recipe>. Run `just vpn` to list them.

host := "jackyyeh@192.168.0.197"
conn := "jackyyeh-mws_linux"

# List recipes
[private]
default:
    @{{just_executable()}} --justfile {{justfile()}} --list vpn

# Turn the VPN on, forward localhost:9000 to 10.0.0.105:2019 and open it in Chrome; Ctrl-C turns it all off
up:
    #!/usr/bin/env bash
    set -euo pipefail
    ssh -t {{host}} 'sudo nmcli --ask connection up id {{conn}}'
    # Set only once the VPN is up, so a failed login has nothing to undo
    trap "ssh -t {{host}} 'sudo nmcli connection down id {{conn}}'" EXIT
    # Open Chrome once the tunnel listens; gives up after 10s
    (for _ in {1..20}; do
        if nc -z localhost 9000 2>/dev/null; then open -a "Google Chrome" http://localhost:9000; break; fi
        sleep 0.5
    done) &
    ssh -o ExitOnForwardFailure=yes -NL 9000:10.0.0.105:2019 {{host}}

# Turn the VPN off
down:
    ssh -t {{host}} 'sudo nmcli connection down id {{conn}}'
