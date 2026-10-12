{
  name = "sola-mpd";

  nodes.machine =
    { pkgs, ... }:
    {
      services.sola-mpd = {
        enable = true;
        port = 3100;
        openFirewall = true;
      };
      services.sola-mpd-subsonic = {
        enable = true;
        port = 3101;
        openFirewall = true;
      };
      environment.systemPackages = [ pkgs.curl ];
      virtualisation.memorySize = 768;
    };

  testScript = ''
    import json
    import shlex

    start_all()
    machine.wait_for_unit("sola-mpd.service")
    machine.wait_for_unit("sola-mpd-subsonic.service")
    machine.wait_for_open_port(3100)
    machine.wait_for_open_port(3101)

    html = machine.succeed("curl --fail http://127.0.0.1:3100/")
    assert "<title>Sola MPD</title>" in html

    initialize = {
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {
            "protocolVersion": "2025-03-26", "capabilities": {},
            "clientInfo": {"name": "nixos-test", "version": "1"},
        },
    }
    body = machine.succeed(
        "curl --fail -H 'Content-Type: application/json' "
        "-H 'Accept: application/json, text/event-stream' --data "
        + shlex.quote(json.dumps(initialize)) + " http://127.0.0.1:3100/mcp"
    )
    if body.startswith("event:"):
        body = next(line[6:] for line in body.splitlines() if line.startswith("data: "))
    result = json.loads(body)
    assert result["result"]["serverInfo"]["name"] == "sola-mpd"

    registration = json.loads(machine.succeed(
        "curl --fail -H 'Content-Type: application/json' -d '{}' "
        "http://127.0.0.1:3101/sola.PluginService/Register"
    ))
    assert registration["info"]["name"] == "Subsonic"
    assert registration["info"]["version"]
    assert registration["info"]["requiredPluginParameters"]

    machine.succeed(
        "curl --fail http://127.0.0.1:3100/api/configs/browser_state -o /tmp/state.bin; "
        "curl --fail -H 'Content-Type: application/octet-stream' "
        "--data-binary @/tmp/state.bin http://127.0.0.1:3100/api/configs/browser_state"
    )
    machine.succeed("test -s /var/lib/sola-mpd/db/browser_state.json")
    machine.succeed("systemctl restart sola-mpd.service")
    machine.wait_for_open_port(3100)
    machine.succeed(
        "curl --fail http://127.0.0.1:3100/api/configs/browser_state -o /tmp/state-after.bin; "
        "cmp /tmp/state.bin /tmp/state-after.bin"
    )

    # The firewall is open: failure verifies loopback binding, not firewall rules.
    address = machine.succeed("hostname -I | cut -d' ' -f1").strip()
    assert address and address != "127.0.0.1"
    for port in (3100, 3101):
        machine.fail(f"curl --noproxy '*' --connect-timeout 2 --fail http://{address}:{port}/")
  '';
}
