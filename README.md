# DbOps
[![CI](https://github.com/cao7113/db_ops/actions/workflows/ci.yml/badge.svg)](https://github.com/cao7113/db_ops/actions/workflows/ci.yml)
[![Release](https://github.com/cao7113/db_ops/actions/workflows/release.yml/badge.svg)](https://github.com/cao7113/db_ops/actions/workflows/release.yml)
[![Hex](https://img.shields.io/hexpm/v/db_ops)](https://hex.pm/packages/db_ops)

Lightweight runtime db management utility for Elixir/Ecto Releases without Mix.

## Installation

Add `db_ops` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:db_ops, "~> 0.2"}
  ]
end
```

## Database management command list for release

Since `db_ops` is packaged into your release, you can run database tasks directly without Mix.

### 1. Print the normalized PostgreSQL URL

```bash
./bin/my_app eval 'IO.puts(DbOps.psql_url(:my_app))'
```

This is the most useful command for prod debugging or shell scripting because it always returns a stable `postgres://...` URL.

### 2. Connect with psql directly

```bash
psql "$(./bin/my_app eval 'IO.puts(DbOps.psql_url(:my_app))')"
```

### 3. Run a single SQL query

```bash
psql "$(./bin/my_app eval 'IO.puts(DbOps.psql_url(:my_app))')" -c "SELECT current_database(), current_user;"
```

### 4. Run SQL from a file

```bash
psql "$(./bin/my_app eval 'IO.puts(DbOps.psql_url(:my_app))')" -f ./sql/check_db.sql
```

### 5. Create database

```bash
./bin/my_app eval "DbOps.create(:my_app)"
```

### 6. Run seeds

```bash
./bin/my_app eval "DbOps.seed(:my_app)"
```

### 7. Check database status

```bash
./bin/my_app eval "DbOps.status(:my_app)"
```

### 8. Drop database (safety enforced)

```bash
# Refused without confirmation
./bin/my_app eval "DbOps.drop(:my_app)"

# Confirmed execution
./bin/my_app eval "DbOps.drop(:my_app, confirm: \"YES_DELETE_DATABASE\")"
```

## Get psql connection string from `DATABASE_URL`

- https://ecto.hexdocs.pm/Ecto.Repo.html#module-urls
- https://ecto-sql.hexdocs.pm/3.14.0/Ecto.Adapters.Postgres.html#module-connection-options
- `DATABASE_URL` in prod env
  - The schema can be of any value and the path represents the database name.
  - `ecto://postgres:postgres@localhost/ecto_simple`
  - `ecto://postgres:postgres@localhost/ecto_simple?ssl=true&pool_size=10`
  - `postgres://postgres:postgres@localhost:5432/my_app_prod?sslmode=disable`
- `MyApp.Repo.config()`

The library can normalize either a repo config or an Ecto-style URL into a stable `psql`-ready PostgreSQL URL:

```elixir
DbOps.psql_url(:my_app)
# => "postgres://postgres:postgres@localhost:5432/my_app_prod?sslmode=disable"

DbOps.psql_url("ecto://postgres:postgres@localhost/ecto_simple?ssl=true&pool_size=10")
# => "postgres://postgres:postgres@localhost:5432/ecto_simple?sslmode=require"
```

### Example: one-liner for production ops

```bash
psql "$(./bin/my_app eval 'IO.puts(DbOps.psql_url(:my_app))')" -c "\l+"
```

This is the most convenient release-safe pattern for quick database inspection in production.