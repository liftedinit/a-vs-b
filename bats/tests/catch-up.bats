GIT_ROOT="$BATS_TEST_DIRNAME/../../"

load '../test_helper/load'

function setup() {
    mkdir "$BATS_TEST_ROOTDIR"
    cd "$GIT_ROOT" || exit

    (
      make clean
    ) > /dev/null
}

function teardown() {
    (
      cd "$GIT_ROOT" || exit
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

@test "$SUITE: TM34 node can catch up" {
    for i in {2..4}
    do
        make NB_NODES_34=2 NB_NODES_35=2 NODE="${i}" start-single-node-background || {
          echo Could not start nodes... >&3
          exit 1
        }
    done

    # Give time to the servers to start.
    sleep 30
    timeout 60s bash <<EOT
    while ! many message --server http://localhost:8002 status; do
      sleep 1
    done >/dev/null
EOT

    check_consistency "$(pem 1)" 1000000000 8004 8002 8003
    ledger "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    check_consistency "$(pem 1)" 999999000 8004 8002 8003
    check_consistency "$(pem 2)" 1000 8004 8002 8003

    ledger "$(pem 1)" 8002 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8002 send "$(identity 2)" 1000 MFX
    check_consistency "$(pem 1)" 999997000 8004 8002 8003
    check_consistency "$(pem 2)" 3000 8004 8002 8003

    ledger "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    check_consistency "$(pem 1)" 999994000 8004 8002 8003
    check_consistency "$(pem 2)" 6000 8004 8002 8003

    ledger "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    check_consistency "$(pem 1)" 999990000 8004 8002 8003
    check_consistency "$(pem 2)" 10000 8004 8002 8003

    # Sleep longer than the MANY message timeout
    sleep 320

    # At this point, start the 4th node and check it can catch up
    cd "$GIT_ROOT" || exit
    make NB_NODES_34=2 NB_NODES_35=2 NODE="1" start-single-node-background || {
      echo Could not start nodes... >&3
      exit 1
    }

    # Give the missing node some time to boot
    sleep 30
    timeout 30s bash <<EOT
    while ! many message --server http://localhost:8004 status; do
      sleep 1
    done >/dev/null
EOT
    sleep 12  # Three consensus round.
    check_consistency "$(pem 1)" 999990000 8001 8002 8003 8004
    check_consistency "$(pem 2)" 10000 8001 8002 8003 8004
}

@test "$SUITE: TM35 node can catch up" {
    for i in {1..3}
    do
        make NB_NODES_34=2 NB_NODES_35=2 NODE="${i}" start-single-node-background || {
          echo Could not start nodes... >&3
          exit 1
        }
    done

    # Give time to the servers to start.
    sleep 30
    timeout 60s bash <<EOT
    while ! many message --server http://localhost:8002 status; do
      sleep 1
    done >/dev/null
EOT

    check_consistency "$(pem 1)" 1000000000 8001 8002 8003
    ledger "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    check_consistency "$(pem 1)" 999999000 8001 8002 8003
    check_consistency "$(pem 2)" 1000 8001 8002 8003

    ledger "$(pem 1)" 8002 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8002 send "$(identity 2)" 1000 MFX
    check_consistency "$(pem 1)" 999997000 8001 8002 8003
    check_consistency "$(pem 2)" 3000 8001 8002 8003

    ledger "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    check_consistency "$(pem 1)" 999994000 8001 8002 8003
    check_consistency "$(pem 2)" 6000 8001 8002 8003

    ledger "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    check_consistency "$(pem 1)" 999990000 8001 8002 8003
    check_consistency "$(pem 2)" 10000 8001 8002 8003

    # Sleep longer than the MANY message timeout
    sleep 320

    # At this point, start the 4th node and check it can catch up
    cd "$GIT_ROOT" || exit
    make NB_NODES_34=2 NB_NODES_35=2 NODE="4" start-single-node-background || {
      echo Could not start nodes... >&3
      exit 1
    }

    # Give the missing node some time to boot
    sleep 30
    timeout 30s bash <<EOT
    while ! many message --server http://localhost:8004 status; do
      sleep 1
    done >/dev/null
EOT
    sleep 12  # Three consensus round.
    check_consistency "$(pem 1)" 999990000 8001 8002 8003 8004
    check_consistency "$(pem 2)" 10000 8001 8002 8003 8004
}
