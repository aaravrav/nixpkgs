{
  name = "lainbow";

  nodes.machine =
    { pkgs, ... }:
    {
      services.lainbow = {
        enable = true;
        # The API needs real MuQ-MuLan weights; tests must not fetch them.
        api.enable = false;
        musicDirectory = "/srv/music";
        inference.port = 8101;
      };
      systemd.tmpfiles.rules = [ "d /srv/music 0755 root root -" ];
      environment.systemPackages = [ pkgs.curl ];
      virtualisation.memorySize = 1536;
    };

  testScript = ''
    import json

    start_all()
    for unit in ("postgresql", "rabbitmq", "qdrant", "lainbow-inference", "lainbow-worker"):
        machine.wait_for_unit(f"{unit}.service")
    machine.wait_for_open_port(8101)
    health = json.loads(machine.succeed("curl --fail http://127.0.0.1:8101/health"))
    assert health == {"status": "ok"}
    machine.succeed("curl --fail http://127.0.0.1:6333/healthz")
    machine.succeed("su -s /bin/sh lainbow -c 'psql -d lainbow -Atc \"SELECT 1\"'")
    machine.wait_until_succeeds(
        "journalctl -u lainbow-worker.service --no-pager | grep -F 'ready.'"
    )

    machine.succeed("printf invalid > /tmp/input.npy")
    status = machine.succeed(
        "curl -s -o /tmp/error.json -w '%{http_code}' "
        "-F 'file=@/tmp/input.npy' http://127.0.0.1:8101/api/v1/inference/unknown-model"
    )
    assert status == "404"
    assert "not found" in json.loads(machine.succeed("cat /tmp/error.json"))["detail"]
    machine.succeed("test -z \"$(ls -A /var/lib/lainbow/models)\"")
    machine.fail("systemctl is-active lainbow-api.service")
  '';
}
