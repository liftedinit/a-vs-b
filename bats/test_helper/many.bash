function pem() {
    echo "$GIT_ROOT/id/id${1}.pem"
}

function _identity() {
    local id="$1"
    local path="$2"
    command "$GIT_ROOT/${path}/many" id "${id}"
}

# Default to many_a
function identity() {
    identity_a "$1"
}

# Default to many_a
function identity_hex() {
    identity_a_hex "$1"
}

function identity_a() {
    _identity "$(pem "$1")" "a-bins"
}

function identity_a_hex() {
    _identity $(_identity "$(pem $1)" "a-bins") "a-bins"
}

function identity_b() {
    _identity "$(pem "$1")" "b-bins"
}

function identity_b_hex() {
    _identity $(_identity "$(pem $1)" "b-bins") "b-bins"
}

function call_many() {
    local pem="$1"
    local port="$2"
    local path="$3"
    shift 3

    run "$GIT_ROOT/${path}/many" message --pem "$pem" --server "http://localhost:${port}/" "$@"
}

function many_a() {
    local pem="$1"
    local port="$2"
    shift 2
    call_many "$pem" "$port" "a-bins" "$@"
}

function many_b() {
    local pem="$1"
    local port="$2"
    shift 2
    call_many "$pem" "$port" "b-bins" "$@"
}

function wait_for_block() {
    local block
    local port
    local current
    block=$1
    port=$2
    # Using [0-9] instead of \d for grep 3.8
    # https://salsa.debian.org/debian/grep/-/blob/debian/master/NEWS
    current=$(many message --server http://localhost:${port}/ blockchain.info | grep -oE '1: [0-9]+' | colrm 1 3)
    while [ "$current" -lt "$block" ]; do
      sleep 1
      current=$(many message --server http://localhost:${port}/ blockchain.info | grep -oE '1: [0-9]+' | colrm 1 3)
    done >/dev/null
}

