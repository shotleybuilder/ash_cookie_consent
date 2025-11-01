defmodule AshCookieConsent.ConsentSettings do
  @moduledoc """
  Ash Resource for tracking cookie consent settings.

  Stores user consent preferences with full audit trail for GDPR compliance.

  ## Attributes

  - `terms` - Policy version identifier (e.g., "v1.0", "2025-01-01")
  - `groups` - Array of consented cookie categories (e.g., ["essential", "analytics"])
  - `consented_at` - Timestamp when consent was given
  - `expires_at` - When consent expires (typically 12 months from consent_at)

  ## Relationships

  - `user` - Optional belongs_to relationship (configurable by implementing app)

  ## Actions

  - `:create` - Create new consent record
  - `:read` - Read consent records
  - `:update` - Update consent preferences
  - `:destroy` - Remove consent record
  - `:grant_consent` - Custom action to grant consent with automatic timestamps
  - `:revoke_consent` - Custom action to revoke consent for specific groups

  ## Examples

      # Create consent
      AshCookieConsent.ConsentSettings
      |> Ash.Changeset.for_create(:grant_consent, %{
        terms: "v1.0",
        groups: ["essential", "analytics"]
      })
      |> Ash.create!()

      # Update consent
      consent
      |> Ash.Changeset.for_update(:update, %{
        groups: ["essential"]
      })
      |> Ash.update!()
  """

  use Ash.Resource,
    domain: AshCookieConsent.Domain,
    extensions: []

  attributes do
    uuid_primary_key :id

    attribute :terms, :string do
      description "Policy version identifier (e.g., 'v1.0', '2025-01-01')"
      allow_nil? false
      public? true
    end

    attribute :groups, {:array, :string} do
      description "Consented cookie categories (e.g., ['essential', 'analytics'])"
      default []
      public? true
    end

    attribute :consented_at, :utc_datetime do
      description "When user provided consent"
      public? true
    end

    attribute :expires_at, :utc_datetime do
      description "When consent expires (typically 12 months after consented_at)"
      public? true
    end

    # Standard Ash timestamps
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  # Relationships section - optional, can be added by implementing app
  # Commented out by default since user module varies by app
  #
  # relationships do
  #   belongs_to :user, YourApp.Accounts.User do
  #     allow_nil? true
  #   end
  # end

  actions do
    defaults [:read, :destroy]

    # Standard CRUD operations
    create :create do
      description "Create a new consent record"
      primary? true

      accept [:terms, :groups, :consented_at, :expires_at]

      change fn changeset, _context ->
        changeset
        |> Ash.Changeset.force_change_attribute(
          :consented_at,
          DateTime.utc_now() |> DateTime.truncate(:second)
        )
        |> Ash.Changeset.force_change_attribute(
          :expires_at,
          DateTime.utc_now()
          |> DateTime.add(365, :day)
          |> DateTime.truncate(:second)
        )
      end
    end

    update :update do
      description "Update consent preferences"
      primary? true

      accept [:terms, :groups, :expires_at]
    end

    # Custom actions for common consent operations
    create :grant_consent do
      description "Grant consent for specific cookie groups"

      accept [:terms, :groups]

      change fn changeset, _context ->
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        expires = DateTime.add(now, 365, :day) |> DateTime.truncate(:second)

        changeset
        |> Ash.Changeset.force_change_attribute(:consented_at, now)
        |> Ash.Changeset.force_change_attribute(:expires_at, expires)
      end
    end

    update :revoke_consent do
      description "Revoke consent for specific cookie groups"

      accept [:groups]

      change fn changeset, _context ->
        # Update groups while maintaining other attributes
        changeset
      end
    end

    read :active_consents do
      description "Get consents that haven't expired"

      filter expr(is_nil(expires_at) or expires_at > ^DateTime.utc_now())
    end
  end

  code_interface do
    define :create
    define :read
    define :update
    define :destroy
    define :grant_consent
    define :revoke_consent
    define :active_consents
  end

  validations do
    validate fn changeset, _context ->
      case Ash.Changeset.get_attribute(changeset, :terms) do
        nil ->
          {:error, field: :terms, message: "must be present"}

        terms when is_binary(terms) and byte_size(terms) > 0 ->
          :ok

        _ ->
          {:error, field: :terms, message: "must be a non-empty string"}
      end
    end

    validate fn changeset, _context ->
      case Ash.Changeset.get_attribute(changeset, :groups) do
        nil ->
          :ok

        groups when is_list(groups) ->
          if Enum.all?(groups, &is_binary/1) do
            :ok
          else
            {:error, field: :groups, message: "must be a list of strings"}
          end

        _ ->
          {:error, field: :groups, message: "must be a list"}
      end
    end
  end

  # Policies can be added by implementing apps
  # Example:
  #
  # policies do
  #   policy always() do
  #     authorize_if always()
  #   end
  # end
end
