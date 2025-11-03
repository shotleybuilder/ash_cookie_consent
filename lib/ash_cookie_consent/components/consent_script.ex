defmodule AshCookieConsent.Components.ConsentScript do
  @moduledoc """
  Phoenix Component for conditionally loading scripts based on cookie consent.

  Only renders the script tag if the user has consented to the specified cookie group.
  Helps ensure GDPR compliance by preventing tracking scripts from loading without consent.

  ## Features

  - Conditional script rendering based on consent
  - Support for external scripts (src attribute)
  - Support for inline scripts (slot content)
  - Support for async/defer attributes
  - Support for custom data attributes

  ## Usage

  ### External Script

      <.consent_script
        consent={@consent}
        group="analytics"
        src="https://www.googletagmanager.com/gtag/js?id=GA_ID"
      />

  ### Inline Script

      <.consent_script consent={@consent} group="analytics">
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());
        gtag('config', 'GA_MEASUREMENT_ID');
      </.consent_script>

  ### With Async/Defer

      <.consent_script
        consent={@consent}
        group="marketing"
        src="https://connect.facebook.net/en_US/fbevents.js"
        async={true}
      />

  ### With Custom Attributes

      <.consent_script
        consent={@consent}
        group="analytics"
        src="https://example.com/script.js"
        data_domain="example.com"
      />

  ## Common Examples

  ### Google Analytics (gtag.js)

      <.consent_script
        consent={@consent}
        group="analytics"
        src={"https://www.googletagmanager.com/gtag/js?id=\#{@ga_id}"}
        async={true}
      />

      <.consent_script consent={@consent} group="analytics">
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());
        gtag('config', '<%= @ga_id %>');
      </.consent_script>

  ### Google Tag Manager

      <.consent_script consent={@consent} group="analytics">
        (function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
        new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
        j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
        'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
        })(window,document,'script','dataLayer','<%= @gtm_id %>');
      </.consent_script>

  ### Facebook Pixel

      <.consent_script
        consent={@consent}
        group="marketing"
        src="https://connect.facebook.net/en_US/fbevents.js"
        async={true}
        defer={true}
      />

      <.consent_script consent={@consent} group="marketing">
        !function(f,b,e,v,n,t,s)
        {if(f.fbq)return;n=f.fbq=function(){n.callMethod?
        n.callMethod.apply(n,arguments):n.queue.push(arguments)};
        if(!f._fbq)f._fbq=n;n.push=n;n.loaded=!0;n.version='2.0';
        n.queue=[];t=b.createElement(e);t.async=!0;
        t.src=v;s=b.getElementsByTagName(e)[0];
        s.parentNode.insertBefore(t,s)}(window, document,'script',
        'https://connect.facebook.net/en_US/fbevents.js');
        fbq('init', '<%= @fb_pixel_id %>');
        fbq('track', 'PageView');
      </.consent_script>

  ### Plausible Analytics

      <.consent_script
        consent={@consent}
        group="analytics"
        src="https://plausible.io/js/script.js"
        defer={true}
        data_domain="example.com"
      />
  """

  use Phoenix.Component

  attr(:consent, :map, default: nil, doc: "Current consent settings map")
  attr(:group, :string, required: true, doc: "Cookie group required for this script")
  attr(:src, :string, default: nil, doc: "External script URL")
  attr(:async, :boolean, default: false, doc: "Add async attribute to script tag")
  attr(:defer, :boolean, default: false, doc: "Add defer attribute to script tag")
  attr(:type, :string, default: "text/javascript", doc: "Script MIME type")

  # Allow custom data attributes
  attr(:rest, :global, doc: "Additional HTML attributes (e.g., data-domain)")

  slot(:inner_block, doc: "Inline script content")

  def consent_script(assigns) do
    # Check if user has consented to this group
    has_consent =
      if assigns.consent && assigns.consent[:groups] do
        assigns.group in assigns.consent.groups
      else
        # If no consent data, don't load (except for essential)
        assigns.group == "essential"
      end

    assigns = assign(assigns, :has_consent, has_consent)

    ~H"""
    <%= if @has_consent do %>
      <script
        :if={@src}
        type={@type}
        src={@src}
        async={@async}
        defer={@defer}
        {@rest}
      >
      </script>
      <script :if={@inner_block != []} type={@type} {@rest}>
        <%= render_slot(@inner_block) %>
      </script>
    <% end %>
    """
  end
end
