# DbOps

Lightweight runtime db management utility for Elixir/Ecto Releases without Mix.

## Installation

Add `db_ops` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:db_ops, "~> 0.1.0"}
  ]
end
```

## Usage in Releases

Since `db_ops` is packaged into your release, you can run database management tasks directly using `eval`:

### 1. Create Database
```bash
./bin/my_app eval "DbOps.create(:my_app)"
```

### 2. Run Seeds
```bash
./bin/my_app eval "DbOps.seed(:my_app)"
```

### 3. Drop Database (Safety Enforced)
```bash
# Will fail due to safety check
./bin/my_app eval "DbOps.drop(:my_app)"

# Confirmed execution
./bin/my_app eval "DbOps.drop(:my_app, confirm: \"YES_DELETE_DATABASE\")"
```