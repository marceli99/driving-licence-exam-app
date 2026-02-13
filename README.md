#### X

Simple App for driving license practice test.

### Database Bundle (easy production import)

Export full PostgreSQL data and local ActiveStorage files:

```bash
bin/rails "db:bundle:export[tmp/db_bundle/prod_seed]"
```

Import on target environment (destructive, replaces DB; by default also restores `storage/`):

```bash
FORCE=true bin/rails "db:bundle:import[tmp/db_bundle/prod_seed]"
```

Useful flags:

- `INCLUDE_STORAGE=false` during export to skip `storage.tar.gz`
- `IMPORT_STORAGE=false` during import to restore only database
- `REPLACE_STORAGE=false` during import to merge storage files instead of replacing

### Seeds Snapshot (full current DB to seeds)

Export full current DB into a seed snapshot file:

```bash
bin/rails "db:seeds:export_snapshot[db/seeds/full_snapshot.json.gz]"
```

Load it on target environment:

```bash
RAILS_ENV=production FORCE=true SNAPSHOT_PATH=db/seeds/full_snapshot.json.gz bin/rails db:seed
```

or:

```bash
RAILS_ENV=production FORCE=true bin/rails "db:seeds:import_snapshot[db/seeds/full_snapshot.json.gz]"
```

Notes:

- This replaces data in all application tables (destructive by design).
- It restores DB rows, but not the actual files from `storage/`; copy storage separately if needed.
