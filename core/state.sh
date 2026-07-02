#!/bin/bash

declare -A STATE
STATE[target_ip]=""
STATE[target_domain]=""
STATE[is_alive]="false"
STATE[open_ports]=""
STATE[web_ports]=""
STATE[discovered_pages]=""
STATE[discovered_vhosts]=""
STATE[added_hosts]=""
STATE[lhost]=""
STATE[lport]=""

STATE[web_server_pid]=""
STATE[shadow_share_445_started]="false"
STATE[shadow_share_445_pid]=""
STATE[shadow_share_2049_started]="false"
STATE[shadow_share_2049_pid]=""