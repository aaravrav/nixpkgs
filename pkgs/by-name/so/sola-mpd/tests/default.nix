{
  lib,
  runCommand,
  python3,
  nodejs,
  package,
}:
runCommand "sola-mpd-web-test"
  {
    nativeBuildInputs = [
      python3
      nodejs
    ];
  }
  ''
    # Verify that the deployed native SQLite binding works, not just HTTP startup.
    node --input-type=module - <<'JS'
    import { createRequire } from 'node:module';
    import assert from 'node:assert/strict';
    const require = createRequire('${package}/lib/sola-mpd/packages/backend/package.json');
    const Database = require('better-sqlite3');
    const db = new Database(':memory:');
    assert.equal(db.prepare('SELECT 42 AS value').get().value, 42);
    assert.throws(() => db.prepare('SELECT * FROM nonexistent_table').get());
    db.close();
    JS

    python ${./web.py} ${lib.getExe' package "sola-mpd-server"}
    touch "$out"
  ''
