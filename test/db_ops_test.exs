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
  end

  setup do
    original = Application.get_env(:db_ops, :ecto_repos)

    on_exit(fn ->
      if original == nil do
        Application.delete_env(:db_ops, :ecto_repos)
      else
        Application.put_env(:db_ops, :ecto_repos, original)
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

  test "drop/2 runs adapter storage_down when confirmed" do
    Application.put_env(:db_ops, :ecto_repos, [FakeRepo])

    assert DbOps.drop(:db_ops, confirm: "YES_DELETE_DATABASE") == :ok
  end
end
