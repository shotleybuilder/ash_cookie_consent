defmodule AshCookieConsent.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/shotleybuilder/ash_cookie_consent"

  def project do
    [
      app: :ash_cookie_consent,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "AshCookieConsent",
      source_url: @source_url,
      homepage_url: @source_url,
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {AshCookieConsent.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # Ash Framework
      {:ash, "~> 3.0"},

      # Phoenix & LiveView
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},

      # JSON encoding
      {:jason, "~> 1.4"},

      # Optional: PostgreSQL data layer (users can choose their own)
      {:ash_postgres, "~> 2.0", optional: true},

      # Dev/Test
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    """
    GDPR-compliant cookie consent management for Ash Framework applications.
    Provides Phoenix Components, LiveView integration, and database persistence
    for tracking user consent with full audit trail.
    """
  end

  defp package do
    [
      name: "ash_cookie_consent",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "#{@source_url}/blob/main/CHANGELOG.md",
        "Sponsor" => "https://github.com/sponsors/shotleybuilder"
      },
      maintainers: ["Jason (Sertantai)"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md usage-rules.md),
      keywords: [
        "ash",
        "ash-framework",
        "cookie",
        "consent",
        "gdpr",
        "privacy",
        "phoenix",
        "liveview",
        "compliance",
        "cookies",
        "tracking",
        "analytics"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/getting-started.md",
        "guides/migration-guide.md",
        "guides/examples.md",
        "guides/troubleshooting.md",
        "guides/extending.md"
      ],
      groups_for_extras: [
        Guides: ~r/guides\/.*/
      ],
      groups_for_modules: [
        Core: [
          AshCookieConsent,
          AshCookieConsent.ConsentSettings
        ],
        "Phoenix Integration": [
          AshCookieConsent.Plug,
          AshCookieConsent.LiveView.Hook,
          AshCookieConsent.Storage,
          AshCookieConsent.Cookie
        ],
        Components: [
          AshCookieConsent.Components.ConsentModal,
          AshCookieConsent.Components.ConsentScript
        ],
        Configuration: [
          AshCookieConsent.Config
        ]
      ]
    ]
  end
end
