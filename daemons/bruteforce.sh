#!/bin/bash

run_parallel_task() {
    local target=$1
    local payload=$2
    sleep "0.$((RANDOM % 9 + 1))"
    if [ "$payload" == "root" ]; then
        echo -e "${CORE}[!] ACCESS GRANTED -> Payload: ${payload}${NC}"
    else
        echo -e "${VOID}[-] Access denied -> Payload: ${payload}${NC}"
    fi
}

run_bruteforce() {
    local target=$1
    local payloads=("admin" "root" "user" "test" "guest" "sysadmin" "operator")
    local max_jobs=3
    local active_jobs=0

    echo -e "\n${NEON}[*] Инициализация многопоточного модуля (MAX_JOBS: $max_jobs)...${NC}"

    for payload in "${payloads[@]}"; do
        run_parallel_task "$target" "$payload" &
        ((active_jobs++))
        if (( active_jobs >= max_jobs )); then
            wait -n
            ((active_jobs--))
        fi
    done

    wait
    echo -e "${SCARLET}[*] Модуль Brute завершил работу.${NC}"
}