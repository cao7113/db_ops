defmodule DbOps do
  @moduledoc """
  Lightweight runtime db management utility for Elixir/Ecto Releases.

  Designed to be invoked via `eval` on release binaries in production/staging environments
  where Mix is not installed.
  """

  @doc """
  Creates all databases associated with the application's Ecto repos.

  ## Examples

      # In release execution:
      # ./bin/my_app eval "DbOps.create(:my_app)"
  """
  @spec create(atom()) :: :ok
  def create(app) when is_atom(app) do
    load_app(app)

    for repo <- repos(app) do
      repo_config = repo.config()
      repo_adapter = repo.__adapter__()

      case repo_adapter.storage_up(repo_config) do
        :ok ->
          IO.puts("✅ [DbOps] Database created successfully for #{inspect(repo)}")

        {:error, :already_up} ->
          IO.puts("ℹ️ [DbOps] Database already exists for #{inspect(repo)}")

        {:error, term} ->
          IO.puts("❌ [DbOps] Failed to create database for #{inspect(repo)}: #{inspect(term)}")
      end
    end

    :ok
  end

  @doc """
  Runs the database seed script.

  Defaults to `priv/repo/seeds.exs` inside the application's priv directory.

  ## Examples

      # ./bin/my_app eval "DbOps.seed(:my_app)"
      # ./bin/my_app eval "DbOps.seed(:my_app, \"priv/repo/custom_seeds.exs\")"
  """
  @spec seed(atom(), String.t() | nil) :: :ok | {:error, :seed_not_found}
  def seed(app, seed_file \\ nil) when is_atom(app) do
    load_app(app)

    # 启动所有 Repo 进程以便 seeds.exs 能够正常执行数据库查询/插入
    for repo <- repos(app) do
      repo.start_link()
    end

    target_seed = seed_file || Path.join([:code.priv_dir(app), "repo", "seeds.exs"])

    if File.exists?(target_seed) do
      IO.puts("🌱 [DbOps] Executing seeds script: #{target_seed}")
      Code.eval_file(target_seed)
      IO.puts("✅ [DbOps] Seeds script completed successfully.")
      :ok
    else
      IO.puts("⚠️ [DbOps] Seeds script not found at: #{target_seed}")
      {:error, :seed_not_found}
    end
  end

  @doc """
  Drops all databases associated with the application's Ecto repos.

  Requires explicit confirmation parameter to prevent accidental deletion in production.

  ## Examples

      # Refused execution:
      # ./bin/my_app eval "DbOps.drop(:my_app)"

      # Confirmed execution:
      # ./bin/my_app eval "DbOps.drop(:my_app, confirm: \"YES_DELETE_DATABASE\")"
  """
  @spec drop(atom(), keyword()) :: :ok | {:error, :confirmation_required}
  def drop(app, opts \\ []) when is_atom(app) do
    load_app(app)

    if Keyword.get(opts, :confirm) != "YES_DELETE_DATABASE" do
      IO.puts("""
      ⛔ [DbOps] Refused to drop database!
         Safety check failed: missing required option `confirm: "YES_DELETE_DATABASE"`.
         Usage: DbOps.drop(:#{app}, confirm: "YES_DELETE_DATABASE")
      """)

      {:error, :confirmation_required}
    else
      for repo <- repos(app) do
        repo_config = repo.config()
        repo_adapter = repo.__adapter__()

        case repo_adapter.storage_down(repo_config) do
          :ok ->
            IO.puts("🔥 [DbOps] Database dropped successfully for #{inspect(repo)}")

          {:error, :already_down} ->
            IO.puts("ℹ️ [DbOps] Database does not exist for #{inspect(repo)}")

          {:error, term} ->
            IO.puts("❌ [DbOps] Failed to drop database for #{inspect(repo)}: #{inspect(term)}")
        end
      end

      :ok
    end
  end

  # ==========================================
  # Helpers
  # ==========================================

  @spec repos(atom()) :: [module()]
  defp repos(app) when is_atom(app) do
    Application.fetch_env!(app, :ecto_repos)
  end

  @spec load_app(atom()) :: :ok
  defp load_app(app) when is_atom(app) do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(app)
    :ok
  end
end
