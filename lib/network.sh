#!/usr/bin/env bash
# Network utilities

test_gentoo_mirrors() {
    log_info "Testing Gentoo mirror connectivity..."
    
    local mirrors=(
        "distfiles.gentoo.org"
        "mirror.leaseweb.com"
        "gentoo.osuosl.org"
    )
    
    local working_mirrors=0
    for mirror in "${mirrors[@]}"; do
        # Try both ping and HTTP check
        if ping -c 1 -W 3 "$mirror" &>/dev/null; then
            log_success "Reachable (ping): $mirror"
            working_mirrors=$((working_mirrors + 1))
        else
            # Try HTTP check as fallback
            if command -v curl &>/dev/null; then
                if curl -f -s -I "https://$mirror" --connect-timeout 5 &>/dev/null; then
                    log_success "Reachable (HTTP): $mirror"
                    working_mirrors=$((working_mirrors + 1))
                else
                    log_error "Unreachable: $mirror"
                fi
            elif command -v wget &>/dev/null; then
                if wget -q --spider --timeout=5 "https://$mirror" &>/dev/null; then
                    log_success "Reachable (HTTP): $mirror"
                    working_mirrors=$((working_mirrors + 1))
                else
                    log_error "Unreachable: $mirror"
                fi
            else
                log_error "Unreachable: $mirror (no HTTP client to test)"
            fi
        fi
    done
    
    if [[ $working_mirrors -eq 0 ]]; then
        log_error "No Gentoo mirrors are reachable"
        return 1
    else
        log_success "$working_mirrors mirror(s) are reachable"
        return 0
    fi
}

test_http_download() {
    local test_urls=(
        "https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt"
        "https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-systemd.txt"
    )
    
    for test_url in "${test_urls[@]}"; do
        log_info "Testing HTTP download from: $test_url"
        
        if command -v curl &>/dev/null; then
            if curl -f -s --connect-timeout 10 "$test_url" | head -n 5 &>/dev/null; then
                log_success "HTTP test passed with curl: $test_url"
                # Also test if we can parse the content
                local content=$(curl -f -s --connect-timeout 10 "$test_url")
                if [[ -n "$content" ]]; then
                    log_info "Content preview of $test_url:"
                    echo "$content" | head -n 3 | while read line; do
                        log_info "  $line"
                    done
                fi
                return 0
            fi
        elif command -v wget &>/dev/null; then
            if wget -q --timeout=10 -O - "$test_url" | head -n 5 &>/dev/null; then
                log_success "HTTP test passed with wget: $test_url"
                return 0
            fi
        fi
    done
    
    log_error "HTTP download test failed for all URLs"
    return 1
}
