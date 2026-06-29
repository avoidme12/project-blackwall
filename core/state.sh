#!/bin/bash

declare -A STATE
STATE[target_ip]=""
STATE[is_alive]="false"
STATE[open_ports]=""
STATE[web_ports]=""
STATE[discovered_vhosts]=""