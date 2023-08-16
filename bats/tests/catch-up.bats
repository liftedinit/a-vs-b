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
    cd "$GIT_ROOT/bats/tests" || exit 1
}


@test "$SUITE: node A can catch up" {
    for i in {2..4}
    do
        make NB_NODES_A=2 NB_NODES_B=2 NODE="${i}" start-single-node-background || {
          echo Could not start nodes... >&3
          exit 1
        }
    done

    # Give time to the servers to start.
    sleep 30
    timeout 60s bash <<EOT
    while ! "$GIT_ROOT/a-bins/many" message --server http://localhost:8002 status; do
      sleep 1
    done >/dev/null
EOT

    check_consistency_a "$(pem 1)" 1000000000 8002
    check_consistency_b "$(pem 1)" 1000000000 8003 8004

    ledger_b "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    check_consistency_a "$(pem 1)" 999999000 8002
    check_consistency_b "$(pem 1)" 999999000 8003 8004
    check_consistency_a "$(pem 2)" 1000 8002
    check_consistency_b "$(pem 2)" 1000 8003 8004

    ledger_a "$(pem 1)" 8002 send "$(identity 2)" 1000 MFX
    ledger_a "$(pem 1)" 8002 send "$(identity 2)" 1000 MFX
    check_consistency_a "$(pem 1)" 999997000 8002
    check_consistency_b "$(pem 1)" 999997000 8003 8004
    check_consistency_a "$(pem 2)" 3000 8002
    check_consistency_b "$(pem 2)" 3000 8003 8004

    ledger_b "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    ledger_b "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    ledger_b "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    check_consistency_a "$(pem 1)" 999994000 8002
    check_consistency_b "$(pem 1)" 999994000 8003 8004
    check_consistency_a "$(pem 2)" 6000 8002
    check_consistency_b "$(pem 2)" 6000 8003 8004

    ledger_b "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    ledger_b "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    ledger_b "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    ledger_b "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    check_consistency_a "$(pem 1)" 999990000 8002
    check_consistency_b "$(pem 1)" 999990000 8003 8004
    check_consistency_a "$(pem 2)" 10000 8002
    check_consistency_b "$(pem 2)" 10000 8003 8004

    # Sleep longer than the MANY message timeout
    sleep 320

    # At this point, start the 4th node and check it can catch up
    cd "$GIT_ROOT" || exit
    make NB_NODES_A=2 NB_NODES_B=2 NODE="1" start-single-node-background || {
      echo Could not start nodes... >&3
      exit 1
    }

    # Give the missing node some time to boot
    sleep 30
    timeout 30s bash <<EOT
    while ! "$GIT_ROOT/b-bins/many" message --server http://localhost:8004 status; do
      sleep 1
    done >/dev/null
EOT
    sleep 12
    check_consistency_a "$(pem 1)" 999990000 8001 8002
    check_consistency_b "$(pem 1)" 999990000 8003 8004
    check_consistency_a "$(pem 2)" 10000 8001 8002
    check_consistency_b "$(pem 2)" 10000 8003 8004
}

@test "$SUITE: node B can catch up" {
    for i in {1..3}
    do
        make NB_NODES_A=2 NB_NODES_B=2 NODE="${i}" start-single-node-background || {
          echo Could not start nodes... >&3
          exit 1
        }
    done

    # Give time to the servers to start.
    sleep 30
    timeout 60s bash <<EOT
    while ! "$GIT_ROOT/a-bins/many" message --server http://localhost:8002 status; do
      sleep 1
    done >/dev/null
EOT

    check_consistency_a "$(pem 1)" 1000000000 8001 8002
    check_consistency_b "$(pem 1)" 1000000000 8003

    ledger_a "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    check_consistency_a "$(pem 1)" 999999000 8001 8002
    check_consistency_b "$(pem 1)" 999999000 8003
    check_consistency_a "$(pem 2)" 1000 8001 8002
    check_consistency_b "$(pem 2)" 1000 8003

    ledger_a "$(pem 1)" 8002 send "$(identity 2)" 1000 MFX
    ledger_a "$(pem 1)" 8002 send "$(identity 2)" 1000 MFX
    check_consistency_a "$(pem 1)" 999997000 8001 8002
    check_consistency_b "$(pem 1)" 999997000 8003
    check_consistency_a "$(pem 2)" 3000 8001 8002
    check_consistency_b "$(pem 2)" 3000 8003

    ledger_b "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    ledger_b "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    ledger_b "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    check_consistency_a "$(pem 1)" 999994000 8001 8002
    check_consistency_b "$(pem 1)" 999994000 8003
    check_consistency_a "$(pem 2)" 6000 8001 8002
    check_consistency_b "$(pem 2)" 6000 8003

    ledger_a "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    ledger_a "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    ledger_a "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    ledger_a "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX
    check_consistency_a "$(pem 1)" 999990000 8001 8002
    check_consistency_b "$(pem 1)" 999990000 8003
    check_consistency_a "$(pem 2)" 10000 8001 8002
    check_consistency_b "$(pem 2)" 10000 8003

    # Sleep longer than the MANY message timeout
    sleep 320

    # At this point, start the 4th node and check it can catch up
    cd "$GIT_ROOT" || exit
    make NB_NODES_A=2 NB_NODES_B=2 NODE="4" start-single-node-background || {
      echo Could not start nodes... >&3
      exit 1
    }

    # Give the missing node some time to boot
    sleep 30
    timeout 30s bash <<EOT
    while ! "$GIT_ROOT/b-bins/many" message --server http://localhost:8004 status; do
      sleep 1
    done >/dev/null
EOT
    sleep 12
    check_consistency_a "$(pem 1)" 999990000 8001 8002
    check_consistency_b "$(pem 1)" 999990000 8003 8004
    check_consistency_a "$(pem 2)" 10000 8001 8002
    check_consistency_b "$(pem 2)" 10000 8003 8004
}
