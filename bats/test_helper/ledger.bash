function call_ledger() {
    local pem="$1"
    local port="$2"
    local path="$3"
    shift 3
    run "$GIT_ROOT/${path}/ledger" --pem "$pem" "http://localhost:${port}/" "$@"
}

function call_ledger_anon() {
    local port="$1"
    local path="$2"
    shift 2
    run "$GIT_ROOT/${path}/ledger" "http://localhost:${port}/" "$@"
}

function check_consistency() {
    local identity="$1"
    local expected_balance="$2"
    local path="$3"
    shift 3

    for port in "$@"; do
        call_ledger_anon "$port" "$path" balance "$identity"
        assert_output --partial " $expected_balance MFX "
    done
}

function ledger_a() {
    local pem="$1"
    local port="$2"
    shift 2
    call_ledger "$pem" "$port" "a-bins" "$@"
}

function ledger_b() {
    local pem="$1"
    local port="$2"
    shift 2
    call_ledger "$pem" "$port" "b-bins" "$@"
}

function check_consistency_a() {
    local identity="$1"
    local expected_balance="$2"
    shift 2
    check_consistency "$identity" "$expected_balance" "a-bins" "$@"
}

function check_consistency_b() {
    local identity="$1"
    local expected_balance="$2"
    shift 2
    check_consistency "$identity" "$expected_balance" "b-bins" "$@"
}
