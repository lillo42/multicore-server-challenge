defmodule ConduitWeb.ErrorJSON do
  @moduledoc "Fallback for unmatched routes / unexpected errors: the errors.body shape."

  def render(template, _assigns) do
    %{errors: %{body: [Phoenix.Controller.status_message_from_template(template)]}}
  end
end
