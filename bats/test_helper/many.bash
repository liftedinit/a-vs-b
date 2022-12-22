function pem() {
    echo "$GIT_ROOT/id/id${1}.pem"
}

function identity() {
    command many id "$(pem "$1")"
}

function identity_hex() {
    command many id $(many id "$(pem "$1")")
}
