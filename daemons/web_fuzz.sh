#!/bin/bash

if [ -z "${STATE[open_ports]}" ]; then
    echo -e "${TXT_CORE}${TXT_ITLC} Target neural network acquired. Data migration to primary matrix - complete.${NC}"
    return
fi