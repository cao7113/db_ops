defmodule DbOps.Utils do
  @moduledoc false

  @spec default_app() :: atom()
  def default_app do
    Application.fetch_env!(:db_ops, :default_app)
  end

  @spec repos(atom()) :: [module() | {module(), keyword()}]
  def repos(app) when is_atom(app) do
    Application.fetch_env!(app, :ecto_repos)
  end

  @spec load_app(atom()) :: :ok
  def load_app(app) when is_atom(app) do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(app)
    :ok
  end

  @spec compact_db_config(keyword() | map()) :: String.t()
  def compact_db_config(config) when is_list(config) do
    compact_db_config_keys(config)
  end

  def compact_db_config(config) when is_map(config) do
    Map.take(config, [:hostname, :database, :username])
    |> Enum.filter(fn {_key, value} -> value not in [nil, ""] end)
    |> Enum.map_join(", ", fn {key, value} -> "#{key}=#{value}" end)
    |> case do
      "" -> inspect(config)
      summary -> summary
    end
  end

  def compact_db_config(config) do
    inspect(config)
  end

  defp compact_db_config_keys(config) do
    [:hostname, :database, :username]
    |> Enum.reduce([], fn key, acc ->
      case Keyword.get(config, key) do
        nil -> acc
        "" -> acc
        value -> [{key, value} | acc]
      end
    end)
    |> Enum.reverse()
    |> Enum.map_join(", ", fn {key, value} -> "#{key}=#{value}" end)
    |> case do
      "" -> inspect(config)
      summary -> summary
    end
  end
end
