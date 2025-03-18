# White ICE
Simple network and device(personal and server) hardening script for UNIX based machines. (Very much inspired by the concept of [ICE](https://en.wikipedia.org/wiki/Intrusion_Countermeasures_Electronics) from the
cyberpunk universe)

## About
White ICE aims to be a rudimentary script that can be run on any UNIX based machine to secure it and setup
intrusion detections via logging and alerts.
Originally made for a distro my friend and I are developing, this would work for basic hardening on any machine.

## How to use
- Clone the repo
- `cd` into `WHITE_ICE`
- run the following command --> `sudo sh whiteice.sh`
- Enter your sudo password and let the sript do its thing

## What it does
- Removes openssh server
- Enables basic firewall
- Setup fail2ban for logging
- Clam AV (antivirus) setup
- Setup AIDE for advanced intrusion detection and file changes (settup a cronjob for this)
- sysctl config for network + kernel hardening

**Note:** This is aimed at Desktop enivronments and not server machines.

## Contribution
If you've found any bugs or errors in the script, please open an issue. If you want to make additions to the
script while being in scope of the project, please feel free to do so.

## License
This script is licensed under the MIT License