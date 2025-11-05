defmodule AshCookieConsent.Domain do
  @moduledoc """
  Ash Domain for cookie consent management.

  This domain contains the ConsentSettings resource and provides
  a clean API for consent operations.
  """

  use Ash.Domain,
    validate_config_inclusion?: false

  resources do
    resource(AshCookieConsent.ConsentSettings)
  end
end
