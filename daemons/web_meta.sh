#!/bin/bash

run_shadow_web_meta() {
    local target=$1
    local port=$2
    local log_file=$3

    if [ "$port" == "21" ]; then
        echo "INFO:21|Initiating FTP anonymous login sweep..." >> "$log_file"

        local ftp_check=$(curl -s --connect-timeout 3 "ftp://${target}/" --user anonymous:anonymous 2>/dev/null)

        if [ $? -eq 0 ]; then
            echo "INFO:21|FTP ANONYMOUS ACCESS GRANTED!" >> "$log_file"
            if [ -n "$ftp_check" ]; then
                echo "INFO:21|Root directory contents:" >> "$log_file"
                echo "$ftp_check" | while read -r line; do
                    echo "INFO:21|  -> ${line}" >> "$log_file"
                done
            else
                echo "INFO:21|  -> [ Directory is empty ]" >> "$log_file"
            fi
        fi
    fi

    if [ "$port" == "443" ]; then
        echo "INFO:443|Extracting SSL/TLS Certificate metadata..." >> "$log_file"

        local ssl_domains=$(openssl s_client -connect "${target}:443" -servername "${target}" 2>/dev/null </dev/null \
                            | openssl x509 -text -noout 2>/dev/null \
                            | grep -oP '(?<=DNS:)[a-zA-Z0-9.-]+' | sort -u)

        if [ -n "$ssl_domains" ]; then
            echo "INFO:443|Discovered domains in TLS Certificate SAN:" >> "$log_file"
            echo "$ssl_domains" | while read -r domain; do
                echo "INFO:443|  -> Domain found: ${domain}" >> "$log_file"
                add_to_hosts "${target}" "${domain}"
            done
        fi
    fi

    if [[ "$port" == "80" || "$port" == "443" ]]; then
        local schema="http"
        if [ "$port" == "443" ]; then schema="https"; fi

        local host_target="${target}"
        if [ -n "${STATE[target_domain]}" ]; then
            host_target="${STATE[target_domain]}"
        fi

        local robots_content=$(curl -s --connect-timeout 3 "${schema}://${host_target}/robots.txt")
        if [[ -n "$robots_content" && "$robots_content" == *"Disallow"* ]]; then
            echo "INFO:${port}|Found robots.txt. Disallowed paths:" >> "$log_file"
            echo "$robots_content" | grep -Ei 'Disallow|Allow' | while read -r line; do
                echo "INFO:${port}|  -> ${line}" >> "$log_file"
            done
        fi

        local index_content=$(curl -s --connect-timeout 3 "${schema}://${host_target}/")
        local comments=$(echo "$index_content" | grep -oP '<!--.*?-->' | sort -u)
        if [ -n "$comments" ]; then
            echo "INFO:${port}|Extracted HTML developer comments:" >> "$log_file"
            echo "$comments" | while read -r line; do
                local clean_comment=$(echo "$line" | sed 's/<!--//g' | sed 's/-->//g' | xargs)
                echo "INFO:${port}|  -> ${clean_comment}" >> "$log_file"
            done
        fi
    fi
}