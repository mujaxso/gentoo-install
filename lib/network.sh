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
        if ping -c 1 -W 2 "$mirror" &>/dev/null; then
            log_success "Reachable: $mirror"
            working_mirrors=$((working_mirrors + 1))
        else
            log_error "Unreachable: $mirror"
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
    local test_url="https://distfiles.gentoo.org/releases/amd64/autobuilds/latest-stage3-amd64-openrc.txt"
    log_info "Testing HTTP download from: $test_url"
    
    if command -v curl &>/dev/null; then
        if curl -f -s -I "$test_url" &>/dev/null; then
            log_success "HTTP test passed with curl"
            return 0
        fi
    elif command -v wget &>/dev/null; then
        if wget -q --spider "$test_url" &>/dev/null; then
            log_success "HTTP test passed with wget"
            return 0
        fi
    fi
    
    log_error "HTTP download test failed"
    return 1
}
