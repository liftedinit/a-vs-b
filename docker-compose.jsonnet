local generate_balance_flags(id_with_balances="", token="mqbfbahksdwaqeenayy2gxke32hgb7aq4ao4wt745lsfs6wiaaaaqnz") =
    if std.length(id_with_balances) == 0 then
        []
    else std.map(
        function(x) (
             local g = std.split(x, ":");
             local id = g[0];
             local amount = if std.length(g) > 1 then g[1] else "10000000000";
             "--balance-only-for-testing=" + std.join(":", [id, amount, token])
        ),
        std.split(id_with_balances, " ")
    );

local load_migrations(enable_migrations) =
    if enable_migrations then
        ["--migrations-config=/genfiles/migrations.json"]
    else
        [];

local generate_allow_addrs_flag(allow_addrs) =
    if allow_addrs then
        ["--allow-addrs=/genfiles/allow_addrs.json5"]
    else
        [];

local abci_command(i) = [
//        "--verbose", "--verbose",
        "--many", "0.0.0.0:8000",
        "--many-app", "http://ledger-" + i + ":8000",
        "--many-pem", "/genfiles/abci.pem",
        "--abci", "0.0.0.0:26658",
        "--tendermint", "http://tendermint-" + i + ":26657/"
    ];

local ledger_command(i) = [
//        "--verbose", "--verbose",
        "--abci",
        "--state=/genfiles/ledger_state.json5",
        "--pem=/genfiles/ledger.pem",
        "--persistent=/persistent/ledger.db",
        "--addr=0.0.0.0:8000",
    ];

local abci_34(i, user, abci_img, allow_addrs) = {
    image: "hybrid/" + abci_img,
    ports: [ (8000 + i) + ":8000" ],
    volumes: [ "./node34_" + i + ":/genfiles:ro" ],
    user: "" + user,
    command: abci_command(i) + generate_allow_addrs_flag(allow_addrs),
    depends_on: [ "ledger-" + i ],
};

local abci_35(i, user, abci_img, allow_addrs) = {
    image: "hybrid/" + abci_img,
    ports: [ (8000 + i) + ":8000" ],
    volumes: [ "./node35_" + i + ":/genfiles:ro" ],
    user: "" + user,
    command: abci_command(i) + generate_allow_addrs_flag(allow_addrs),
    depends_on: [ "ledger-" + i ],
};

local ledger_34(i, user, id_with_balances, ledger_img, enable_migrations) = {
    image: "hybrid/" + ledger_img,
    user: "" + user,
    volumes: [
        "./node34_" + i + "/persistent-ledger:/persistent",
        "./node34_" + i + ":/genfiles:ro",
    ],
    command: ledger_command(i) + load_migrations(enable_migrations)
      + generate_balance_flags(id_with_balances)
};

local ledger_35(i, user, id_with_balances, ledger_img, enable_migrations) = {
    image: "hybrid/" + ledger_img,
    user: "" + user,
    volumes: [
        "./node35_" + i + "/persistent-ledger:/persistent",
        "./node35_" + i + ":/genfiles:ro",
    ],
    command: ledger_command(i) + load_migrations(enable_migrations)
      + generate_balance_flags(id_with_balances)
};

local tendermint_34(i, user, tendermint_tag) = {
    image: "tendermint/tendermint:v" + tendermint_tag,
    command: [
        "start",
        "--rpc.laddr", "tcp://0.0.0.0:26657",
        "--proxy_app", "tcp://abci-" + i + ":26658",
    ],
    user: "" + user,
    volumes: [
        "./node34_" + i + "/tendermint/:/tendermint"
    ],
    ports: [ "" + (26600 + i) + ":26600" ],
};

local tendermint_35(i, user, tendermint_tag) = {
    image: "tendermint/tendermint:v" + tendermint_tag,
    command: [
        "--log-level", "info",
        "start",
        "--rpc.laddr", "tcp://0.0.0.0:26657",
        "--proxy-app", "tcp://abci-" + i + ":26658",
    ],
    user: "" + user,
    volumes: [
        "./node35_" + i + "/tendermint/:/tendermint"
    ],
    ports: [ "" + (26600 + i) + ":26600" ],
};

function(nb_nodes_34=2,
		 nb_nodes_35=2,
		 user=1000,
		 id_with_balances="",
		 tendermint_34_tag="0.34.24",
		 tendermint_35_tag="0.35.4",
		 allow_addrs=false,
		 enable_migrations=false) {
    version: '3',
    services: {
        ["abci-" + i]: abci_34(i, user, "many-abci-34", allow_addrs) for i in std.range(1, nb_nodes_34 )
    } + {
        ["ledger-" + i]: ledger_34(i, user, id_with_balances, "many-ledger-34", enable_migrations) for i in std.range(1, nb_nodes_34)
    } + {
        ["tendermint-" + i]: tendermint_34(i, user, tendermint_34_tag) for i in std.range(1, nb_nodes_34)
    } + {
        ["abci-" + i]: abci_35(i, user, "many-abci-35", allow_addrs) for i in std.range(nb_nodes_34 + 1, nb_nodes_34 + nb_nodes_35)
    } + {
        ["ledger-" + i]: ledger_35(i, user, id_with_balances, "many-ledger-35", enable_migrations) for i in std.range(nb_nodes_34 + 1, nb_nodes_34 + nb_nodes_35)
    } + {
        ["tendermint-" + i]: tendermint_35(i, user, tendermint_35_tag) for i in std.range(nb_nodes_34 + 1, nb_nodes_34 + nb_nodes_35)
    },
}
