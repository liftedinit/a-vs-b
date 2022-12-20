GIT_ROOT="$BATS_TEST_DIRNAME/../../"

load '../test_helper/load'

function setup() {
    mkdir "$BATS_TEST_ROOTDIR"
    cd "$GIT_ROOT" || exit

    (
      make clean
      make NB_NODES_34=2 NB_NODES_35=2 start-nodes-background || {
        echo Could not start nodes... >&3
        exit 1
      }
    ) > /dev/null

    # Give time to the servers to start.
    sleep 30
    timeout 30s bash <<EOT
    while ! many message --server http://localhost:8002 status; do
      sleep 1
    done >/dev/null
EOT
}

function teardown() {
    (
      cd "$GIT_ROOT" || exit 1
      make stop-nodes
    ) 2> /dev/null
}

function ledger() {
    local pem="$1"
    local port="$2"
    shift 2
    run "$GIT_ROOT/tm35-bins/ledger" --pem "$pem" "http://localhost:${port}/" "$@"
}

function check_consistency() {
    local pem="$1"
    local expected_balance="$2"
    shift 2

    for port in "$@"; do
        ledger "$pem" "$port" balance
        assert_output --partial " $expected_balance MFX "
    done
}

@test "$SUITE: Network is consistent with all nodes up" {
    # Check consistency with all nodes up.
    check_consistency "$(pem 1)" 1000000000 8001 8002 8003 8004
    ledger "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    sleep 4  # One consensus round.
    check_consistency "$(pem 1)" 999999000 8001 8002 8003 8004
    check_consistency "$(pem 2)" 1000 8001 8002 8003 8004

    ledger "$(pem 1)" 8002 send "$(identity 2)" 2000 MFX
    sleep 4  # One consensus round.
    check_consistency "$(pem 1)" 999997000 8001 8002 8003 8004
    check_consistency "$(pem 2)" 3000 8001 8002 8003 8004

    ledger "$(pem 1)" 8003 send "$(identity 2)" 3000 MFX
    sleep 4  # One consensus round.
    check_consistency "$(pem 1)" 999994000 8001 8002 8003 8004
    check_consistency "$(pem 2)" 6000 8001 8002 8003 8004

    ledger "$(pem 1)" 8004 send "$(identity 2)" 4000 MFX
    sleep 4  # One consensus round.
    check_consistency "$(pem 1)" 999990000 8001 8002 8003 8004
    check_consistency "$(pem 2)" 10000 8001 8002 8003 8004
}

@test "$SUITE: Network is consistent with 1 TM35 node down" {
    docker stop e2e-ledger-tendermint-4-1

    # Check consistency with all nodes up.
    check_consistency "$(pem 1)" 1000000000 8001 8002 8003
    ledger "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    sleep 10  # One consensus round.
    check_consistency "$(pem 1)" 999999000 8001 8002 8003
    check_consistency "$(pem 2)" 1000 8001 8002 8003

    ledger "$(pem 1)" 8002 send "$(identity 2)" 2000 MFX
    sleep 10  # One consensus round.
    check_consistency "$(pem 1)" 999997000 8001 8002 8003
    check_consistency "$(pem 2)" 3000 8001 8002 8003

    ledger "$(pem 1)" 8003 send "$(identity 2)" 3000 MFX
    sleep 10  # One consensus round.
    check_consistency "$(pem 1)" 999994000 8001 8002 8003
    check_consistency "$(pem 2)" 6000 8001 8002 8003

    docker start e2e-ledger-tendermint-4-1
    # Give time to the servers to start.
    sleep 30
    timeout 30s bash <<EOT
    while ! many message --server http://localhost:8004 status; do
      sleep 1
    done >/dev/null
EOT
    sleep 10
    check_consistency "$(pem 1)" 999994000 8001 8002 8003 8004
    check_consistency "$(pem 2)" 6000 8001 8002 8003 8004
}

@test "$SUITE: Network is consistent with 1 TM34 node down" {
    docker stop e2e-ledger-tendermint-1-1

    # Check consistency with all nodes up.
    check_consistency "$(pem 1)" 1000000000 8004 8002 8003
    ledger "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    sleep 10  # One consensus round.
    check_consistency "$(pem 1)" 999999000 8004 8002 8003
    check_consistency "$(pem 2)" 1000 8004 8002 8003

    ledger "$(pem 1)" 8002 send "$(identity 2)" 2000 MFX
    sleep 10  # One consensus round.
    check_consistency "$(pem 1)" 999997000 8004 8002 8003
    check_consistency "$(pem 2)" 3000 8004 8002 8003

    ledger "$(pem 1)" 8003 send "$(identity 2)" 3000 MFX
    sleep 10  # One consensus round.
    check_consistency "$(pem 1)" 999994000 8004 8002 8003
    check_consistency "$(pem 2)" 6000 8004 8002 8003

    docker start e2e-ledger-tendermint-1-1
    # Give time to the servers to start.
    sleep 30
    timeout 30s bash <<EOT
    while ! many message --server http://localhost:8001 status; do
      sleep 1
    done >/dev/null
EOT
    sleep 10
    check_consistency "$(pem 1)" 999994000 8001 8002 8003 8004
    check_consistency "$(pem 2)" 6000 8001 8002 8003 8004
}
