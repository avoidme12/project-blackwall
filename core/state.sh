#!/bin/bash

declare -A STATE
STATE[target_ip]=""
STATE[is_alive]="false"
STATE[open_ports]="22,80,443"
STATE[web_ports]=""
STATE[discovered_pages=""
STATE[discovered_vhosts]=""