# Admin LXC | What is it for?

The admin LXC replaces the personal workspace.
Instead of having to install k3s-ansible on your local machine, you run it through the LXC.
This enables easy access from everywhere provided a VPN or reverse proxy is setup (opening your admin panel to the Internet isnt reccomended for security reasons).

## Requirements

- Debian 13
- 512 MB RAM
- 10 GB Disk

## Installation

1. Update System
2. Install tools
3. Generate SSH key or insert your own
4. Clone this repo

``` bash
curl -sL https://raw.githubusercontent.com/aaronschm/homelab/refs/heads/main/scripts/admin-setup.sh?token=GHSAT0AAAAAAD432SHX5IOLTHK4JJAYC7CI2QI5R6A | bash
```
