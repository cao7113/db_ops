defmodule DbOps.PsqlUrlTest do
  use ExUnit.Case

  defmodule FakeRepo do
    def config, do: [database: "db_ops_test"]
  end

  setup do
    original = Application.get_env(:db_ops, :ecto_repos)
    original_default_app = Application.get_env(:db_ops, :default_app)

    on_exit(fn ->
      if original == nil do
        Application.delete_env(:db_ops, :ecto_repos)
      else
        Application.put_env(:db_ops, :ecto_repos, original)
      end

      if original_default_app == nil do
        Application.delete_env(:db_ops, :default_app)
      else
        Application.put_env(:db_ops, :default_app, original_default_app)
      end
    end)

    :ok
  end

  test "from_app/1 builds a stable PostgreSQL URL from repo config" do
    Application.put_env(:db_ops, :ecto_repos, [
      {FakeRepo,
       [
         username: "postgres",
         password: "postgres",
         hostname: "localhost",
         port: 5432,
         database: "db_ops_test",
         ssl: false
       ]}
    ])

    assert DbOps.psql_url(:db_ops) ==
             "postgres://postgres:postgres@localhost:5432/db_ops_test?sslmode=disable"
  end

  test "from_url/1 normalizes DATABASE_URL values into a psql-safe URL" do
    Application.put_env(:db_ops, :ecto_repos, [
      {FakeRepo,
       [
         url: "ecto://postgres:postgres@localhost/ecto_simple?ssl=true&pool_size=10",
         database: "ecto_simple"
       ]}
    ])

    assert DbOps.psql_url(:db_ops) ==
             "postgres://postgres:postgres@localhost:5432/ecto_simple?sslmode=require"
  end
end
