defmodule DbOps.PsqlUrl do
  @moduledoc """
  Normalizes Ecto repo configuration and DATABASE_URL values to a stable
  PostgreSQL URL that is safe to pass to `psql` in release builds.
  """

  @spec from_app(atom()) :: String.t()
  def from_app(app) when is_atom(app) do
    app
    |> first_repo_config()
    |> case do
      nil ->
        raise ArgumentError, "No Ecto repo is configured for application #{inspect(app)}"

      repo_config ->
        from_repo_config(repo_config)
    end
  end

  @spec from_repo_config(keyword()) :: String.t()
  def from_repo_config(config) when is_list(config) do
    config
    |> Keyword.get(:url)
    |> case do
      nil ->
        url = System.get_env("DATABASE_URL")

        if is_binary(url) do
          from_url_with_config(url, config)
        else
          from_config(config)
        end

      url ->
        from_url_with_config(url, config)
    end
  end

  @spec from_url(String.t()) :: String.t()
  def from_url(url) when is_binary(url) do
    from_url_with_config(url, [])
  end

  @spec first_repo_config(atom()) :: keyword() | nil
  defp first_repo_config(app) when is_atom(app) do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(app)

    case Application.fetch_env!(app, :ecto_repos) |> List.first() do
      nil -> nil
      {_, repo_config} -> repo_config
      repo when is_atom(repo) -> repo.config()
    end
  end

  @spec from_config(keyword()) :: String.t()
  defp from_config(config) do
    username = Keyword.get(config, :username) || Keyword.get(config, :user)
    password = Keyword.get(config, :password)
    host = Keyword.get(config, :hostname) || Keyword.get(config, :host) || "localhost"
    port = Keyword.get(config, :port) || 5432
    database = Keyword.get(config, :database) || "postgres"
    ssl_mode = normalize_ssl_mode(Keyword.get(config, :ssl), nil)

    format_url(username, password, host, port, database, ssl_mode)
  end

  @spec from_url_with_config(String.t(), keyword()) :: String.t()
  defp from_url_with_config(url, config) when is_binary(url) do
    uri = URI.parse(url)
    {username, password} = parse_userinfo(uri.userinfo)
    username = username || Keyword.get(config, :username) || Keyword.get(config, :user)
    password = password || Keyword.get(config, :password)
    host = uri.host || Keyword.get(config, :hostname) || Keyword.get(config, :host) || "localhost"
    port = uri.port || Keyword.get(config, :port) || 5432

    database =
      case uri.path do
        nil -> Keyword.get(config, :database) || "postgres"
        "" -> Keyword.get(config, :database) || "postgres"
        path -> String.trim_leading(path, "/")
      end

    ssl_mode =
      uri.query
      |> case do
        nil -> normalize_ssl_mode(Keyword.get(config, :ssl), nil)
        query -> normalize_ssl_mode(Keyword.get(config, :ssl), URI.decode_query(query))
      end

    format_url(username, password, host, port, database, ssl_mode)
  end

  @spec normalize_ssl_mode(term(), map() | nil) :: String.t()
  defp normalize_ssl_mode(config_ssl, query_params) do
    query_ssl =
      case query_params do
        nil -> nil
        params -> Map.get(params, "ssl") || Map.get(params, "sslmode")
      end

    cond do
      query_ssl in ["true", true] -> "require"
      query_ssl in ["false", false] -> "disable"
      config_ssl == true -> "require"
      config_ssl == false -> "disable"
      true -> "disable"
    end
  end

  @spec format_url(
          String.t() | nil,
          String.t() | nil,
          String.t(),
          integer(),
          String.t(),
          String.t()
        ) ::
          String.t()
  defp format_url(nil, _password, host, port, database, ssl_mode) do
    "postgres://#{host}:#{port}/#{database}?sslmode=#{ssl_mode}"
  end

  defp format_url(username, password, host, port, database, ssl_mode) do
    user = URI.encode_www_form(username)

    pass =
      if is_binary(password) && password != "", do: ":#{URI.encode_www_form(password)}", else: ""

    "postgres://#{user}#{pass}@#{host}:#{port}/#{database}?sslmode=#{ssl_mode}"
  end

  @spec parse_userinfo(String.t() | nil) :: {String.t() | nil, String.t() | nil}
  defp parse_userinfo(nil), do: {nil, nil}

  defp parse_userinfo(userinfo) when is_binary(userinfo) do
    case String.split(userinfo, ":", parts: 2) do
      [user] -> {user, nil}
      [user, password] -> {user, password}
    end
  end
end
