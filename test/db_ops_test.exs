defmodule DbOpsTest do
  use ExUnit.Case
  doctest DbOps

  defmodule FakeRepo do
    def config, do: [database: "db_ops_test"]
    def __adapter__, do: DbOpsTest.FakeAdapter
    def start_link, do: {:ok, self()}
  end

  defmodule FakeAdapter do
    def storage_up(_config), do: :ok
    def storage_down(_config), do: :ok
    def storage_status(_config), do: :up
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

  test "drop/2 rejects unsafe deletion without confirmation" do
    assert DbOps.drop(:db_ops) == {:error, :confirmation_required}
  end

  test "create/1 runs adapter storage_up for configured repos" do
    Application.put_env(:db_ops, :ecto_repos, [FakeRepo])

    assert DbOps.create(:db_ops) == :ok
  end

  test "create/0 uses the configured default application" do
    Application.put_env(:db_ops, :default_app, :db_ops)
    Application.put_env(:db_ops, :ecto_repos, [FakeRepo])

    assert DbOps.create() == :ok
  end

  test "config/0 returns configurations for the default application's repos" do
    Application.put_env(:db_ops, :default_app, :db_ops)
    Application.put_env(:db_ops, :ecto_repos, [FakeRepo])

    assert DbOps.config() == [{FakeRepo, [database: "db_ops_test"]}]
  end

  test "status/0 uses the configured default application" do
    Application.put_env(:db_ops, :default_app, :db_ops)
    Application.put_env(:db_ops, :ecto_repos, [FakeRepo])

    assert DbOps.status() == :ok
  end

  test "drop/2 runs adapter storage_down when confirmed" do
    Application.put_env(:db_ops, :ecto_repos, [FakeRepo])

    assert DbOps.drop(:db_ops, confirm: "YES_DELETE_DATABASE") == :ok
  end
end
