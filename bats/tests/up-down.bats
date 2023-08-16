GIT_ROOT="$BATS_TEST_DIRNAME/../../"

load '../test_helper/load'

function setup() {
    mkdir "$BATS_TEST_ROOTDIR"
    cd "$GIT_ROOT" || exit

    (
      make clean
      make NB_NODES_A=2 NB_NODES_B=2 start-nodes-background || {
        echo Could not start nodes... >&3
        exit 1
      }
    ) > /dev/null

    # Give time to the servers to start.
    sleep 30
    timeout 30s bash <<EOT
    while ! "$GIT_ROOT/a-bins/many" message --server http://localhost:8002 status; do
      sleep 1
    done >/dev/null
EOT
}

function teardown() {
    (
      cd "$GIT_ROOT" || exit 1
      make stop-nodes
    ) 2> /dev/null
    cd "$GIT_ROOT/bats/tests" || exit 1
}

@test "$SUITE: Network is consistent with all nodes up" {
    # Check consistency with all nodes up.
    check_consistency_a "$(pem 1)" 1000000000 8001 8002
    check_consistency_b "$(pem 1)" 1000000000 8003 8004

    ledger_a "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    check_consistency_a "$(pem 1)" 999999000 8001 8002
    check_consistency_b "$(pem 1)" 999999000 8003 8004
    check_consistency_a "$(pem 2)" 1000 8001 8002
    check_consistency_b "$(pem 2)" 1000 8003 8004

    ledger_a "$(pem 1)" 8002 send "$(identity 2)" 2000 MFX
    check_consistency_a "$(pem 1)" 999997000 8001 8002
    check_consistency_b "$(pem 1)" 999997000 8003 8004
    check_consistency_a "$(pem 2)" 3000 8001 8002
    check_consistency_b "$(pem 2)" 3000 8003 8004

    ledger_b "$(pem 1)" 8003 send "$(identity 2)" 3000 MFX
    check_consistency_a "$(pem 1)" 999994000 8001 8002
    check_consistency_b "$(pem 1)" 999994000 8003 8004
    check_consistency_a "$(pem 2)" 6000 8001 8002
    check_consistency_b "$(pem 2)" 6000 8003 8004

    ledger_b "$(pem 1)" 8004 send "$(identity 2)" 4000 MFX
    check_consistency_a "$(pem 1)" 999990000 8001 8002
    check_consistency_b "$(pem 1)" 999990000 8003 8004
    check_consistency_a "$(pem 2)" 10000 8001 8002
    check_consistency_b "$(pem 2)" 10000 8003 8004
}

@test "$SUITE: Network is consistent with 1 node B down, tx after" {
    docker stop e2e-ledger-tendermint-4-1

    # Check consistency with all nodes up.
    check_consistency_a "$(pem 1)" 1000000000 8001 8002
    check_consistency_b "$(pem 1)" 1000000000 8003

    ledger_a "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    check_consistency_a "$(pem 1)" 999999000 8001 8002
    check_consistency_b "$(pem 1)" 999999000 8003
    check_consistency_a "$(pem 2)" 1000 8001 8002
    check_consistency_b "$(pem 2)" 1000 8003

    ledger_a "$(pem 1)" 8002 send "$(identity 2)" 2000 MFX
    check_consistency_a "$(pem 1)" 999997000 8001 8002
    check_consistency_b "$(pem 1)" 999997000 8003
    check_consistency_a "$(pem 2)" 3000 8001 8002
    check_consistency_b "$(pem 2)" 3000 8003

    ledger_b "$(pem 1)" 8003 send "$(identity 2)" 3000 MFX
    check_consistency_a "$(pem 1)" 999994000 8001 8002
    check_consistency_b "$(pem 1)" 999994000 8003
    check_consistency_a "$(pem 2)" 6000 8001 8002
    check_consistency_b "$(pem 2)" 6000 8003

    docker start e2e-ledger-tendermint-4-1
    # Give time to the servers to start.
    sleep 30
    timeout 30s bash <<EOT
    while ! "$GIT_ROOT/b-bins/many" message --server http://localhost:8004 status; do
      sleep 1
    done >/dev/null
EOT
    sleep 10
    check_consistency_a "$(pem 1)" 999994000 8001 8002
    check_consistency_b "$(pem 1)" 999994000 8003 8004
    check_consistency_a "$(pem 2)" 6000 8001 8002
    check_consistency_b "$(pem 2)" 6000 8003 8004
}

@test "$SUITE: Network is consistent with 1 node B down, tx before and after" {
    check_consistency_a "$(pem 1)" 1000000000 8001 8002
    check_consistency_b "$(pem 1)" 1000000000 8003

    ledger_a "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    check_consistency_a "$(pem 1)" 999999000 8001 8002
    check_consistency_b "$(pem 1)" 999999000 8003
    check_consistency_a "$(pem 2)" 1000 8001 8002
    check_consistency_b "$(pem 2)" 1000 8003

    docker stop e2e-ledger-tendermint-4-1

    ledger_a "$(pem 1)" 8002 send "$(identity 2)" 2000 MFX
    check_consistency_a "$(pem 1)" 999997000 8001 8002
    check_consistency_b "$(pem 1)" 999997000 8003
    check_consistency_a "$(pem 2)" 3000 8001 8002
    check_consistency_b "$(pem 2)" 3000 8003

    ledger_b "$(pem 1)" 8003 send "$(identity 2)" 3000 MFX
    check_consistency_a "$(pem 1)" 999994000 8001 8002
    check_consistency_b "$(pem 1)" 999994000 8003
    check_consistency_a "$(pem 2)" 6000 8001 8002
    check_consistency_b "$(pem 2)" 6000 8003

    docker start e2e-ledger-tendermint-4-1

    # Give time to the servers to start.
    sleep 30
    timeout 30s bash <<EOT
    while ! "$GIT_ROOT/b-bins/many" message --server http://localhost:8004 status; do
      sleep 1
    done >/dev/null
EOT
    sleep 10
    check_consistency_a "$(pem 1)" 999994000 8001 8002
    check_consistency_b "$(pem 1)" 999994000 8003 8004
    check_consistency_a "$(pem 2)" 6000 8001 8002
    check_consistency_b "$(pem 2)" 6000 8003 8004
}

@test "$SUITE: Network is consistent with 1 node A down" {
    docker stop e2e-ledger-tendermint-1-1

    # Check consistency with all nodes up.
    check_consistency_a "$(pem 1)" 1000000000 8002
    check_consistency_b "$(pem 1)" 1000000000 8003 8004

    ledger_b "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    check_consistency_a "$(pem 1)" 999999000 8002
    check_consistency_b "$(pem 1)" 999999000 8003 8004
    check_consistency_a "$(pem 2)" 1000 8002
    check_consistency_b "$(pem 2)" 1000 8003 8004

    ledger_a "$(pem 1)" 8002 send "$(identity 2)" 2000 MFX
    check_consistency_a "$(pem 1)" 999997000 8002
    check_consistency_b "$(pem 1)" 999997000 8003 8004
    check_consistency_a "$(pem 2)" 3000 8002
    check_consistency_b "$(pem 2)" 3000 8003 8004

    ledger_b "$(pem 1)" 8003 send "$(identity 2)" 3000 MFX
    check_consistency_a "$(pem 1)" 999994000 8002
    check_consistency_b "$(pem 1)" 999994000 8003 8004
    check_consistency_a "$(pem 2)" 6000 8002
    check_consistency_b "$(pem 2)" 6000 8003 8004

    docker start e2e-ledger-tendermint-1-1
    # Give time to the servers to start.
    sleep 30
    timeout 30s bash <<EOT
    while ! "$GIT_ROOT/a-bins/many" message --server http://localhost:8001 status; do
      sleep 1
    done >/dev/null
EOT
    sleep 10
    check_consistency_a "$(pem 1)" 999994000 8001 8002
    check_consistency_b "$(pem 1)" 999994000 8003 8004
    check_consistency_a "$(pem 2)" 6000 8001 8002
    check_consistency_b "$(pem 2)" 6000 8003 8004
}
