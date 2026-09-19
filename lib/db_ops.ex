defmodule DbOps do
  import DbOps.Utils, only: [load_app: 1, repos: 1, compact_db_config: 1]

  @moduledoc """
  Lightweight runtime database management utility for Elixir/Ecto Releases.

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
  def create(app \\ default_app()) when is_atom(app) do
    load_app(app)

    for repo <- repos(app) do
      repo_config = repo.config()
      repo_adapter = repo.__adapter__()

      case repo_adapter.storage_up(repo_config) do
        :ok ->
          IO.puts("✅ [DbOps] Database created successfully for #{compact_db_config(repo_config)}")

        {:error, :already_up} ->
          IO.puts("ℹ️ [DbOps] Database already exists for #{compact_db_config(repo_config)}")

        {:error, term} ->
          IO.puts(
            "❌ [DbOps] Failed to create database for #{compact_db_config(repo_config)}: #{inspect(term)}"
          )
      end
    end

    :ok
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
            IO.puts(
              "🔥 [DbOps] Database dropped successfully for #{compact_db_config(repo_config)}"
            )

          {:error, :already_down} ->
            IO.puts("ℹ️ [DbOps] Database does not exist for #{compact_db_config(repo_config)}")

          {:error, term} ->
            IO.puts(
              "❌ [DbOps] Failed to drop database for #{compact_db_config(repo_config)}: #{inspect(term)}"
            )
        end
      end

      :ok
    end
  end

  @doc """
  Runs the database seed script.

  Defaults to `priv/repo/seeds.exs` inside the application's priv directory.

  ## Examples

      # ./bin/my_app eval "DbOps.seed(:my_app)"
      # ./bin/my_app eval "DbOps.seed(:my_app, \"priv/repo/custom_seeds.exs\")"
  """
  @spec seed(atom(), String.t() | nil) :: :ok | {:error, :seed_not_found}
  def seed(app \\ default_app(), seed_file \\ nil) when is_atom(app) do
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
  Checks the database status for all Ecto repos associated with the application.

  ## Examples

      # ./bin/my_app eval "DbOps.status()"
      # ./bin/my_app eval "DbOps.status(:my_app)"
  """
  @spec status(atom()) :: :ok
  def status(app \\ default_app()) when is_atom(app) do
    load_app(app)

    for repo <- repos(app) do
      repo_config = repo.config()
      repo_adapter = repo.__adapter__()

      case repo_adapter.storage_status(repo_config) do
        :up ->
          IO.puts("✅ [DbOps] Database is up for #{compact_db_config(repo_config)}")

        :down ->
          IO.puts("ℹ️ [DbOps] Database is down for #{compact_db_config(repo_config)}")

        {:error, term} ->
          IO.puts(
            "❌ [DbOps] Failed to check database status for #{compact_db_config(repo_config)}: #{inspect(term)}"
          )
      end
    end

    :ok
  end

  @doc """
  Returns the configuration for all Ecto repos associated with the application.

  ## Examples

      DbOps.config()
      DbOps.config(:my_app)
  """
  @spec config(atom()) :: [{module(), keyword()}]
  def config(app \\ default_app()) when is_atom(app) do
    load_app(app)

    for repo <- repos(app) do
      {repo, repo.config()}
    end
  end

  @doc """
  Returns a PostgreSQL connection URL that is safe to pass to `psql` in production.

  This method accepts the application's repo config or the `DATABASE_URL` value from
  the runtime environment and normalizes it to a stable `postgres://...` URL.

  ## Examples

      DbOps.psql_url(:my_app)
      DbOps.psql_url(MyApp.Repo.config())
      DbOps.psql_url("ecto://postgres:postgres@localhost/ecto_simple?ssl=true&pool_size=10")
  """
  @spec psql_url(atom() | keyword() | String.t()) :: String.t()
  def psql_url(app \\ default_app()) do
    case app do
      app when is_atom(app) -> DbOps.PsqlUrl.from_app(app)
      config when is_list(config) -> DbOps.PsqlUrl.from_repo_config(config)
      url when is_binary(url) -> DbOps.PsqlUrl.from_url(url)
    end
  end

  # ==========================================
  # Helpers
  # ==========================================

  @doc """
  Returns the application configured as the default target.

  Configure it with `config :db_ops, default_app: :my_app`.
  """
  @spec default_app() :: atom()
  def default_app do
    DbOps.Utils.default_app()
  end
end
