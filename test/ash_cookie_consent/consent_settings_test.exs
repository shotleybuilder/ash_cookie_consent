defmodule AshCookieConsent.ConsentSettingsTest do
  use ExUnit.Case, async: true

  alias AshCookieConsent.ConsentSettings

  describe "create action" do
    test "creates consent with automatic timestamps" do
      # Note: This test will fail until we have a data layer configured
      # For now, it tests the changeset validation
      changeset =
        ConsentSettings
        |> Ash.Changeset.for_create(:create, %{
          terms: "v1.0",
          groups: ["essential", "analytics"]
        })

      assert changeset.valid?
      assert Ash.Changeset.get_attribute(changeset, :terms) == "v1.0"
      assert Ash.Changeset.get_attribute(changeset, :groups) == ["essential", "analytics"]

      # Check that timestamps will be set
      assert Ash.Changeset.get_attribute(changeset, :consented_at) != nil
      assert Ash.Changeset.get_attribute(changeset, :expires_at) != nil
    end

    test "sets consented_at to current time" do
      before = DateTime.utc_now() |> DateTime.truncate(:second)

      changeset =
        ConsentSettings
        |> Ash.Changeset.for_create(:create, %{
          terms: "v1.0",
          groups: ["essential"]
        })

      consented_at = Ash.Changeset.get_attribute(changeset, :consented_at)
      after_time = DateTime.utc_now() |> DateTime.add(1, :second) |> DateTime.truncate(:second)

      assert DateTime.compare(consented_at, before) in [:eq, :gt]
      assert DateTime.compare(consented_at, after_time) in [:eq, :lt]
    end

    test "sets expires_at to 365 days from now" do
      changeset =
        ConsentSettings
        |> Ash.Changeset.for_create(:create, %{
          terms: "v1.0",
          groups: ["essential"]
        })

      expires_at = Ash.Changeset.get_attribute(changeset, :expires_at)
      consented_at = Ash.Changeset.get_attribute(changeset, :consented_at)

      expected_expires = DateTime.add(consented_at, 365, :day)

      # Allow 1 second difference due to timing
      diff = DateTime.diff(expires_at, expected_expires, :second)
      assert abs(diff) <= 1
    end
  end

  describe "grant_consent action" do
    test "creates consent with provided terms and groups" do
      changeset =
        ConsentSettings
        |> Ash.Changeset.for_create(:grant_consent, %{
          terms: "v2.0",
          groups: ["essential", "analytics", "marketing"]
        })

      assert changeset.valid?
      assert Ash.Changeset.get_attribute(changeset, :terms) == "v2.0"

      assert Ash.Changeset.get_attribute(changeset, :groups) == [
               "essential",
               "analytics",
               "marketing"
             ]
    end

    test "automatically sets timestamps" do
      changeset =
        ConsentSettings
        |> Ash.Changeset.for_create(:grant_consent, %{
          terms: "v1.0",
          groups: ["essential"]
        })

      assert Ash.Changeset.get_attribute(changeset, :consented_at) != nil
      assert Ash.Changeset.get_attribute(changeset, :expires_at) != nil
    end
  end

  describe "update action" do
    test "update action exists and accepts correct fields" do
      # Just verify the action exists and is configured correctly
      update_action = Ash.Resource.Info.action(ConsentSettings, :update)

      assert update_action
      assert update_action.type == :update

      # Check that it accepts the right fields
      accept_fields = update_action.accept
      assert :terms in accept_fields or accept_fields == nil
      assert :groups in accept_fields or accept_fields == nil
    end
  end

  describe "validations" do
    test "requires terms to be present" do
      changeset =
        ConsentSettings
        |> Ash.Changeset.for_create(:create, %{
          terms: nil,
          groups: ["essential"]
        })

      refute changeset.valid?

      errors = changeset.errors
      assert Enum.any?(errors, fn error -> error.field == :terms end)
    end

    test "requires terms to be non-empty string" do
      changeset =
        ConsentSettings
        |> Ash.Changeset.for_create(:create, %{
          terms: "",
          groups: ["essential"]
        })

      refute changeset.valid?
    end

    test "accepts valid terms" do
      changeset =
        ConsentSettings
        |> Ash.Changeset.for_create(:create, %{
          terms: "v1.0",
          groups: ["essential"]
        })

      # Check terms validation passed (may still be invalid for other reasons)
      # We're specifically checking that terms validation doesn't add errors
      terms_errors = Enum.filter(changeset.errors, fn error -> error.field == :terms end)
      assert terms_errors == []
    end

    test "requires groups to be a list" do
      changeset =
        ConsentSettings
        |> Ash.Changeset.for_create(:create, %{
          terms: "v1.0",
          groups: "not a list"
        })

      refute changeset.valid?

      errors = changeset.errors
      assert Enum.any?(errors, fn error -> error.field == :groups end)
    end

    test "requires groups to be a list of strings" do
      changeset =
        ConsentSettings
        |> Ash.Changeset.for_create(:create, %{
          terms: "v1.0",
          groups: ["essential", 123, :atom]
        })

      refute changeset.valid?

      errors = changeset.errors
      assert Enum.any?(errors, fn error -> error.field == :groups end)
    end

    test "accepts valid groups" do
      changeset =
        ConsentSettings
        |> Ash.Changeset.for_create(:create, %{
          terms: "v1.0",
          groups: ["essential", "analytics"]
        })

      # Check groups validation passed
      groups_errors = Enum.filter(changeset.errors, fn error -> error.field == :groups end)
      assert groups_errors == []
    end

    test "accepts empty groups list" do
      changeset =
        ConsentSettings
        |> Ash.Changeset.for_create(:create, %{
          terms: "v1.0",
          groups: []
        })

      # Check groups validation passed
      groups_errors = Enum.filter(changeset.errors, fn error -> error.field == :groups end)
      assert groups_errors == []
    end
  end

  describe "attributes" do
    test "has required attributes" do
      # Test that the resource has the expected attributes
      attributes = Ash.Resource.Info.attributes(ConsentSettings)

      attribute_names = Enum.map(attributes, & &1.name)

      assert :id in attribute_names
      assert :terms in attribute_names
      assert :groups in attribute_names
      assert :consented_at in attribute_names
      assert :expires_at in attribute_names
      assert :inserted_at in attribute_names
      assert :updated_at in attribute_names
    end

    test "groups default is empty list" do
      attributes = Ash.Resource.Info.attributes(ConsentSettings)
      groups_attr = Enum.find(attributes, &(&1.name == :groups))

      assert groups_attr.default == []
    end
  end

  describe "actions" do
    test "has expected actions" do
      actions = Ash.Resource.Info.actions(ConsentSettings)
      action_names = Enum.map(actions, & &1.name)

      assert :create in action_names
      assert :read in action_names
      assert :update in action_names
      assert :destroy in action_names
      assert :grant_consent in action_names
      assert :revoke_consent in action_names
      assert :active_consents in action_names
    end

    test "create is the primary create action" do
      create_action = Ash.Resource.Info.action(ConsentSettings, :create)
      assert create_action.primary?
    end

    test "update is the primary update action" do
      update_action = Ash.Resource.Info.action(ConsentSettings, :update)
      assert update_action.primary?
    end
  end

  describe "code interface" do
    test "defines code interface functions" do
      # The code interface functions exist at module level
      # These functions have multiple arities due to Ash's code interface options
      # Just check that the functions exist
      functions = ConsentSettings.__info__(:functions)
      function_names = Keyword.keys(functions) |> Enum.uniq()

      assert :create in function_names
      assert :read in function_names
      assert :update in function_names
      assert :destroy in function_names
      assert :grant_consent in function_names
      assert :revoke_consent in function_names
      assert :active_consents in function_names
    end
  end
end
