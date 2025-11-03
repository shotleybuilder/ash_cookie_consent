defmodule AshCookieConsent.ConfigTest do
  use ExUnit.Case, async: true

  alias AshCookieConsent.Config

  describe "cookie_groups/0" do
    test "returns default cookie groups" do
      groups = Config.cookie_groups()

      assert is_list(groups)
      assert length(groups) == 3

      # Check essential group exists
      essential = Enum.find(groups, &(&1.id == "essential"))
      assert essential
      assert essential.required == true
      assert essential.label
      assert essential.description

      # Check analytics group exists
      analytics = Enum.find(groups, &(&1.id == "analytics"))
      assert analytics
      assert analytics.required == false

      # Check marketing group exists
      marketing = Enum.find(groups, &(&1.id == "marketing"))
      assert marketing
      assert marketing.required == false
    end

    test "all groups have required fields" do
      groups = Config.cookie_groups()

      for group <- groups do
        assert Map.has_key?(group, :id)
        assert Map.has_key?(group, :label)
        assert Map.has_key?(group, :description)
        assert Map.has_key?(group, :required)
      end
    end
  end

  describe "get_group/1" do
    test "returns a specific group by ID" do
      group = Config.get_group("analytics")

      assert group
      assert group.id == "analytics"
      assert group.label == "Analytics Cookies"
    end

    test "returns nil for non-existent group" do
      assert Config.get_group("nonexistent") == nil
    end
  end

  describe "required_groups/0" do
    test "returns only required groups" do
      groups = Config.required_groups()

      assert is_list(groups)
      assert Enum.all?(groups, & &1.required)

      essential = Enum.find(groups, &(&1.id == "essential"))
      assert essential
    end

    test "does not return optional groups" do
      groups = Config.required_groups()

      refute Enum.any?(groups, &(&1.id == "analytics"))
      refute Enum.any?(groups, &(&1.id == "marketing"))
    end
  end

  describe "optional_groups/0" do
    test "returns only optional groups" do
      groups = Config.optional_groups()

      assert is_list(groups)
      assert Enum.all?(groups, &(!&1.required))

      analytics = Enum.find(groups, &(&1.id == "analytics"))
      assert analytics

      marketing = Enum.find(groups, &(&1.id == "marketing"))
      assert marketing
    end

    test "does not return required groups" do
      groups = Config.optional_groups()

      refute Enum.any?(groups, &(&1.id == "essential"))
    end
  end

  describe "validate_groups/1" do
    test "validates correct group configuration" do
      valid_groups = [
        %{
          id: "test",
          label: "Test Group",
          description: "Test description",
          required: false
        }
      ]

      assert Config.validate_groups(valid_groups) == :ok
    end

    test "returns error for missing id field" do
      invalid_groups = [
        %{
          label: "Test Group",
          description: "Test description",
          required: false
        }
      ]

      assert {:error, message} = Config.validate_groups(invalid_groups)
      assert message =~ "missing required field: id"
    end

    test "returns error for missing label field" do
      invalid_groups = [
        %{
          id: "test",
          description: "Test description",
          required: false
        }
      ]

      assert {:error, message} = Config.validate_groups(invalid_groups)
      assert message =~ "missing required field: label"
    end

    test "returns error for missing description field" do
      invalid_groups = [
        %{
          id: "test",
          label: "Test Group",
          required: false
        }
      ]

      assert {:error, message} = Config.validate_groups(invalid_groups)
      assert message =~ "missing required field: description"
    end

    test "returns error for missing required field" do
      invalid_groups = [
        %{
          id: "test",
          label: "Test Group",
          description: "Test description"
        }
      ]

      assert {:error, message} = Config.validate_groups(invalid_groups)
      assert message =~ "missing required field: required"
    end

    test "validates multiple groups" do
      valid_groups = [
        %{
          id: "essential",
          label: "Essential",
          description: "Required",
          required: true
        },
        %{
          id: "analytics",
          label: "Analytics",
          description: "Optional",
          required: false
        }
      ]

      assert Config.validate_groups(valid_groups) == :ok
    end

    test "stops at first invalid group" do
      invalid_groups = [
        %{
          id: "valid",
          label: "Valid",
          description: "Valid",
          required: true
        },
        %{
          # Missing id
          label: "Invalid",
          description: "Invalid",
          required: false
        }
      ]

      assert {:error, _message} = Config.validate_groups(invalid_groups)
    end
  end
end
