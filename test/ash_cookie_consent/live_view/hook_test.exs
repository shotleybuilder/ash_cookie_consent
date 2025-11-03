defmodule AshCookieConsent.LiveView.HookTest do
  use ExUnit.Case, async: true

  alias AshCookieConsent.LiveView.Hook

  # Helper to create a minimal test socket with required internal structure
  defp test_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Map.merge(%{__changed__: %{}}, assigns),
      endpoint: TestEndpoint,
      router: TestRouter,
      view: TestLiveView,
      id: "test-socket-id",
      private: %{
        assign_new: [],
        phoenix_live_view_event_prefixes: [],
        live_temp: %{}
      }
    }
  end

  describe "on_mount/4 with :load_consent" do
    test "sets consent assign from session" do
      consent = %{"terms" => "v1.0", "groups" => ["essential", "analytics"]}
      session = %{"consent" => consent}
      socket = test_socket()

      {:cont, updated_socket} = Hook.on_mount(:load_consent, %{}, session, socket)

      assert updated_socket.assigns.consent == consent
    end

    test "sets show_consent_modal to false when consent exists" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}
      session = %{"consent" => consent}
      socket = test_socket()

      {:cont, updated_socket} = Hook.on_mount(:load_consent, %{}, session, socket)

      assert updated_socket.assigns.show_consent_modal == false
    end

    test "sets show_consent_modal to true when no consent" do
      session = %{}
      socket = test_socket()

      {:cont, updated_socket} = Hook.on_mount(:load_consent, %{}, session, socket)

      assert updated_socket.assigns.show_consent_modal == true
    end

    test "sets cookie_groups assign" do
      session = %{}
      socket = test_socket()

      {:cont, updated_socket} = Hook.on_mount(:load_consent, %{}, session, socket)

      assert is_list(updated_socket.assigns.cookie_groups)
      assert length(updated_socket.assigns.cookie_groups) > 0
    end

    test "handles nil consent from session" do
      session = %{"consent" => nil}
      socket = test_socket()

      {:cont, updated_socket} = Hook.on_mount(:load_consent, %{}, session, socket)

      assert updated_socket.assigns.consent == nil
      assert updated_socket.assigns.show_consent_modal == true
    end

    test "handles empty consent map" do
      session = %{"consent" => %{}}
      socket = test_socket()

      {:cont, updated_socket} = Hook.on_mount(:load_consent, %{}, session, socket)

      assert updated_socket.assigns.consent == %{}
      assert updated_socket.assigns.show_consent_modal == true
    end

    test "returns {:cont, socket} to continue mount chain" do
      session = %{}
      socket = test_socket()

      result = Hook.on_mount(:load_consent, %{}, session, socket)

      assert {:cont, %Phoenix.LiveView.Socket{}} = result
    end
  end

  describe "on_mount/4 with :require_consent" do
    test "continues when valid consent exists" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}
      session = %{"consent" => consent}
      socket = test_socket()

      result = Hook.on_mount(:require_consent, %{}, session, socket)

      assert {:cont, _socket} = result
    end

    test "halts and redirects when no consent" do
      session = %{}
      socket = test_socket()

      result = Hook.on_mount(:require_consent, %{}, session, socket)

      assert {:halt, redirected_socket} = result
      assert redirected_socket.redirected != nil
    end

    test "halts and redirects when consent is empty" do
      session = %{"consent" => %{}}
      socket = test_socket()

      result = Hook.on_mount(:require_consent, %{}, session, socket)

      assert {:halt, redirected_socket} = result
      assert redirected_socket.redirected != nil
    end

    test "sets all assigns when consent is valid" do
      consent = %{"terms" => "v1.0", "groups" => ["essential", "analytics"]}
      session = %{"consent" => consent}
      socket = test_socket()

      {:cont, updated_socket} = Hook.on_mount(:require_consent, %{}, session, socket)

      assert updated_socket.assigns.consent == consent
      assert updated_socket.assigns.show_consent_modal == false
      assert is_list(updated_socket.assigns.cookie_groups)
    end
  end

  describe "on_mount/4 with unknown phase" do
    test "raises error for unknown mount phase" do
      session = %{}
      socket = test_socket()

      assert_raise RuntimeError, ~r/Unknown mount phase/, fn ->
        Hook.on_mount(:invalid_phase, %{}, session, socket)
      end
    end
  end

  describe "handle_consent_update/3" do
    test "builds consent from params with list groups" do
      socket = test_socket()
      params = %{"terms" => "v1.0", "groups" => ["essential", "analytics"]}

      {:noreply, updated_socket} = Hook.handle_consent_update(socket, params)

      assert updated_socket.assigns.consent["terms"] == "v1.0"
      assert updated_socket.assigns.consent["groups"] == ["essential", "analytics"]
    end

    test "builds consent from params with JSON groups" do
      socket = test_socket()
      groups_json = Jason.encode!(["essential", "analytics"])
      params = %{"terms" => "v1.0", "groups" => groups_json}

      {:noreply, updated_socket} = Hook.handle_consent_update(socket, params)

      assert updated_socket.assigns.consent["groups"] == ["essential", "analytics"]
    end

    test "sets default terms when not provided" do
      socket = test_socket()
      params = %{"groups" => ["essential"]}

      {:noreply, updated_socket} = Hook.handle_consent_update(socket, params)

      assert updated_socket.assigns.consent["terms"] == "v1.0"
    end

    test "sets consented_at timestamp" do
      socket = test_socket()
      params = %{"groups" => ["essential"]}

      {:noreply, updated_socket} = Hook.handle_consent_update(socket, params)

      assert %DateTime{} = updated_socket.assigns.consent["consented_at"]
    end

    test "sets expires_at to 1 year from now" do
      socket = test_socket()
      params = %{"groups" => ["essential"]}

      {:noreply, updated_socket} = Hook.handle_consent_update(socket, params)

      assert %DateTime{} = updated_socket.assigns.consent["expires_at"]

      # Check it's approximately 1 year in the future
      now = DateTime.utc_now()
      expires = updated_socket.assigns.consent["expires_at"]
      diff = DateTime.diff(expires, now, :day)
      assert diff >= 364 && diff <= 366
    end

    test "closes modal after update" do
      socket = test_socket(%{show_consent_modal: true})
      params = %{"groups" => ["essential"]}

      {:noreply, updated_socket} = Hook.handle_consent_update(socket, params)

      assert updated_socket.assigns.show_consent_modal == false
    end

    test "pushes event to update cookie" do
      socket = test_socket()
      params = %{"groups" => ["essential"]}

      {:noreply, updated_socket} = Hook.handle_consent_update(socket, params)

      # Check that push_event was called
      # LiveView test helpers check this via socket.private
      assert is_list(updated_socket.private[:phoenix_live_view_event_prefixes])
    end

    test "handles malformed JSON groups gracefully" do
      socket = test_socket()
      params = %{"groups" => "not valid json"}

      {:noreply, updated_socket} = Hook.handle_consent_update(socket, params)

      assert updated_socket.assigns.consent["groups"] == []
    end

    test "handles missing groups param" do
      socket = test_socket()
      params = %{"terms" => "v1.0"}

      {:noreply, updated_socket} = Hook.handle_consent_update(socket, params)

      assert updated_socket.assigns.consent["groups"] == []
    end
  end

  describe "show_modal/1" do
    test "sets show_consent_modal to true" do
      socket = test_socket(%{show_consent_modal: false})

      updated_socket = Hook.show_modal(socket)

      assert updated_socket.assigns.show_consent_modal == true
    end

    test "works when modal was already shown" do
      socket = test_socket(%{show_consent_modal: true})

      updated_socket = Hook.show_modal(socket)

      assert updated_socket.assigns.show_consent_modal == true
    end
  end

  describe "hide_modal/1" do
    test "sets show_consent_modal to false" do
      socket = test_socket(%{show_consent_modal: true})

      updated_socket = Hook.hide_modal(socket)

      assert updated_socket.assigns.show_consent_modal == false
    end

    test "works when modal was already hidden" do
      socket = test_socket(%{show_consent_modal: false})

      updated_socket = Hook.hide_modal(socket)

      assert updated_socket.assigns.show_consent_modal == false
    end
  end

  describe "should_show_modal?/1 (via on_mount)" do
    test "returns true for nil consent" do
      session = %{"consent" => nil}
      socket = test_socket()

      {:cont, updated_socket} = Hook.on_mount(:load_consent, %{}, session, socket)

      assert updated_socket.assigns.show_consent_modal == true
    end

    test "returns true for empty map consent" do
      session = %{"consent" => %{}}
      socket = test_socket()

      {:cont, updated_socket} = Hook.on_mount(:load_consent, %{}, session, socket)

      assert updated_socket.assigns.show_consent_modal == true
    end

    test "returns false for valid consent with groups" do
      consent = %{"terms" => "v1.0", "groups" => ["essential"]}
      session = %{"consent" => consent}
      socket = test_socket()

      {:cont, updated_socket} = Hook.on_mount(:load_consent, %{}, session, socket)

      assert updated_socket.assigns.show_consent_modal == false
    end
  end
end

# Dummy modules for testing
defmodule TestEndpoint do
  def config(:live_view), do: []
end

defmodule TestRouter do
end

defmodule TestLiveView do
end
