# Kandypack database

Run these commands in PowerShell from the `database` folder. The scripts use MySQL 8.0 and create `kandypack_db`.

## Set up a fresh database

Use a disposable MySQL instance. The master script resets the database, so do not run it against a database with data you need to keep.

```powershell
Set-Location Set-Location "your location" (C:\Users)
mysql --no-defaults --protocol=TCP --host=127.0.0.1 --port=33327 --user=root --password --execute='SOURCE 00_master_init.sql'
```

Replace port `33327` with your disposable instance’s port. The master script also runs `10_roster_reporting.sql`, which creates the roster hours reporting view.

If you want to run the files individually, run them in this order from the same folder:

```text
01_schema.sql
02_views.sql
03_procedures.sql
04_triggers.sql
05_indexes.sql
06_seed_data.sql
09_roster_assignment.sql
10_roster_reporting.sql
```

Run `08_roles_and_grants.sql` afterward if you need the database roles and grants.

## Add the reporting view to an existing database

If the roster tables already exist and only the reporting view is missing, run this single script:

```powershell
Set-Location C:\Users\Praghathees\Desktop\Kandypack\database
mysql --no-defaults --protocol=TCP --host=127.0.0.1 --port=3306 --user=root --password --execute='SOURCE 10_roster_reporting.sql'
```

Change the port or user if your MySQL setup uses different values. This command creates the view without resetting your tables or data.