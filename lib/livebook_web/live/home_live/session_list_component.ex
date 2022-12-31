defmodule LivebookWeb.HomeLive.SessionListComponent do
  use LivebookWeb, :live_component

  import Livebook.Utils, only: [format_bytes: 1]
  import LivebookWeb.SessionHelpers

  alias Livebook.{Session, Notebook}

  @impl true
  def mount(socket) do
    {:ok, assign(socket, order_by: "date")}
  end

  @impl true
  def update(assigns, socket) do
    {sessions, assigns} = Map.pop!(assigns, :sessions)

    sessions = sort_sessions(sessions, socket.assigns.order_by)

    show_autosave_note? =
      case Livebook.Settings.autosave_path() do
        nil -> false
        path -> match?({:ok, [_ | _]}, File.ls(path))
      end

    socket =
      socket
      |> assign(assigns)
      |> assign(sessions: sessions, show_autosave_note?: show_autosave_note?)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <form id="bulk-action-form" phx-submit="bulk_action">
      <div class="flex items-center justify-between mb-4 md:items-end">
        <div class="flex flex-row">
          <h2 class="text-sm font-semibold text-gray-500 uppercase md:text-base dark:text-gray-400">
            Running sessions (<%= length(@sessions) %>)
          </h2>
        </div>
        <div class="flex flex-row">
          <.memory_info memory={@memory} />
          <%= if @sessions != [] do %>
            <.edit_sessions sessions={@sessions} socket={@socket} />
          <% end %>
          <.menu id="sessions-order-menu">
            <:toggle>
              <button
                class="flex items-center justify-between px-4 py-1 w-28 button-base button-outlined-gray"
                type="button"
                aria-label={"order by - currently ordered by #{order_by_label(@order_by)}"}
              >
                <span><%= order_by_label(@order_by) %></span>
                <.remix_icon icon="arrow-down-s-line" class="ml-1 text-lg leading-none align-middle" />
              </button>
            </:toggle>
            <:content>
              <%= for order_by <- ["date", "title", "memory"] do %>
                <button
                  class={
                    "menu-item #{if order_by == @order_by, do: "text-gray-900", else: "text-gray-500"}"
                  }
                  type="button"
                  role="menuitem"
                  phx-click={
                    JS.push("set_order", value: %{order_by: order_by}, target: @myself)
                    |> sr_message("ordered by #{order_by}")
                  }
                >
                  <.remix_icon icon={order_by_icon(order_by)} />
                  <span class="font-medium"><%= order_by_label(order_by) %></span>
                </button>
              <% end %>
            </:content>
          </.menu>
        </div>
      </div>
      <.session_list
        sessions={@sessions}
        socket={@socket}
        show_autosave_note?={@show_autosave_note?}
        myself={@myself}
      />
    </form>
    """
  end

  defp session_list(%{sessions: []} = assigns) do
    ~H"""
    <div class="flex items-center p-5 mt-4 border border-gray-200 rounded-lg space-x-4">
      <div>
        <.remix_icon icon="windy-line" class="text-xl text-gray-400" />
      </div>
      <div class="flex items-center justify-between grow">
        <div class="text-gray-600">
          You do not have any running sessions.
          <%= if @show_autosave_note? do %>
            <br />
            Looking for unsaved notebooks? <a
              class="font-semibold"
              href="#"
              phx-click="open_autosave_directory"
            >Browse them here</a>.
          <% end %>
        </div>
        <button class="button-base button-blue" phx-click="new">
          New notebook
        </button>
      </div>
    </div>
    """
  end

  defp session_list(assigns) do
    ~H"""
    <div class="flex flex-col" role="group" aria-label="running sessions list">
      <%= for session <- @sessions do %>
        <div class="flex items-center py-4 border-b border-gray-300" data-test-session-id={session.id}>
          <div id={"#{session.id}-checkbox"} phx-update="ignore">
            <input
              type="checkbox"
              name="session_ids[]"
              value={session.id}
              aria-label={session.notebook_name}
              class="hidden mr-3 checkbox-base"
              data-el-bulk-edit-member
              phx-click={JS.dispatch("lb:session_list:on_selection_change")}
            />
          </div>
          <div class="flex flex-col items-start grow">
            <%= live_redirect(session.notebook_name,
              to: Routes.session_path(@socket, :page, session.id),
              class:
                "font-semibold text-gray-800 hover:text-gray-900 dark:text-gray-100 dark:hover-text-gray-900"
            ) %>
            <div class="text-sm text-gray-600 dark:text-gray-300">
              <%= if session.file, do: session.file.path, else: "No file" %>
            </div>
            <div class="flex flex-row items-center mt-2 text-sm text-gray-600 dark:text-gray-300">
              <%= if uses_memory?(session.memory_usage) do %>
                <div class="w-3 h-3 mr-1 bg-green-500 rounded-full"></div>
                <span class="pr-4"><%= format_bytes(session.memory_usage.runtime.total) %></span>
              <% else %>
                <div class="w-3 h-3 mr-1 bg-gray-300 rounded-full dark:bg-gray-600"></div>
                <span class="pr-4">0 MB</span>
              <% end %>
              Created <%= format_creation_date(session.created_at) %>
            </div>
          </div>
          <.menu id={"session-#{session.id}-menu"}>
            <:toggle>
              <button class="icon-button" aria-label="open session menu" type="button">
                <.remix_icon icon="more-2-fill" class="text-xl" />
              </button>
            </:toggle>
            <:content>
              <a
                class="text-gray-500 menu-item dark:text-gray-400"
                role="menuitem"
                href={
                  Routes.session_path(@socket, :download_source, session.id, "livemd",
                    include_outputs: false
                  )
                }
                download
              >
                <.remix_icon icon="download-2-line" class="text-lg" />
                <span class="font-medium">Download source</span>
              </a>
              <button
                class="text-gray-500 menu-item dark:text-gray-400"
                type="button"
                role="menuitem"
                phx-click="fork_session"
                phx-target={@myself}
                phx-value-id={session.id}
              >
                <.remix_icon icon="git-branch-line" />
                <span class="font-medium">Fork</span>
              </button>
              <a
                class="text-gray-500 menu-item dark:text-gray-400"
                role="menuitem"
                href={live_dashboard_process_path(@socket, session.pid)}
                target="_blank"
              >
                <.remix_icon icon="dashboard-2-line" />
                <span class="font-medium">See on Dashboard</span>
              </a>
              <button
                class="text-gray-500 menu-item dark:text-gray-400"
                type="button"
                disabled={!session.memory_usage.runtime}
                role="menuitem"
                phx-target={@myself}
                phx-click={toggle_edit(:off) |> JS.push("disconnect_runtime")}
                phx-value-id={session.id}
              >
                <.remix_icon icon="shut-down-line" />
                <span class="font-medium">Disconnect runtime</span>
              </button>
              <%= live_patch to: Routes.home_path(@socket, :close_session, session.id),
                    class: "menu-item text-red-600",
                    role: "menuitem" do %>
                <.remix_icon icon="close-circle-line" />
                <span class="font-medium">Close</span>
              <% end %>
            </:content>
          </.menu>
        </div>
      <% end %>
    </div>
    """
  end

  defp memory_info(assigns) do
    %{free: free, total: total} = assigns.memory
    used = total - free
    percentage = Float.round(used / total * 100, 2)
    assigns = assign(assigns, free: free, used: used, total: total, percentage: percentage)

    ~H"""
    <div class="pr-1 lg:pr-4" role="group" aria-label="memory information">
      <span class="tooltip top" data-tooltip={"#{format_bytes(@free)} available"}>
        <svg viewbox="-10 5 50 25" width="30" height="30" xmlns="http://www.w3.org/2000/svg">
          <circle
            cx="16.91549431"
            cy="16.91549431"
            r="15.91549431"
            stroke="#E0E8F0"
            stroke-width="13"
            fill="none"
          />
          <circle
            cx="16.91549431"
            cy="16.91549431"
            r="15.91549431"
            stroke="#3E64FF"
            stroke-dasharray={"#{@percentage},100"}
            stroke-width="13"
            fill="none"
          />
        </svg>
        <div class="hidden sm:flex md:hidden lg:flex">
          <span class="px-2 py-1 text-sm font-medium text-gray-500">
            <%= format_bytes(@used) %> / <%= format_bytes(@total) %>
            <span class="sr-only"><%= @percentage %> percent used</span>
          </span>
        </div>
      </span>
    </div>
    """
  end

  defp edit_sessions(assigns) do
    ~H"""
    <div
      class="flex flex-row mx-4 mr-2 text-gray-600 gap-1"
      role="group"
      aria-label="bulk actions for sessions"
    >
      <.menu id="edit-sessions">
        <:toggle>
          <button
            id="toggle-edit"
            class="px-4 py-1 pl-2 w-28 button-base button-outlined-gray"
            phx-click={toggle_edit(:on)}
            type="button"
            aria-label="toggle edit"
          >
            <.remix_icon icon="list-check-2" class="ml-1 text-lg leading-none align-middle" />
            <span>Edit</span>
          </button>
          <button
            class="flex items-center justify-between hidden px-4 py-1 w-28 button-base button-outlined-gray"
            data-el-bulk-edit-member
            type="button"
          >
            <span>Actions</span>
            <.remix_icon icon="arrow-down-s-line" class="ml-1 text-lg leading-none align-middle" />
          </button>
        </:toggle>
        <:content>
          <button class="text-gray-600 menu-item" phx-click={toggle_edit(:off)} type="button">
            <.remix_icon icon="close-line" />
            <span class="font-medium">Cancel</span>
          </button>
          <button class="text-gray-600 menu-item" phx-click={select_all()} type="button">
            <.remix_icon icon="checkbox-multiple-line" />
            <span class="font-medium">Select all</span>
          </button>
          <button
            class="text-gray-600 menu-item"
            name="disconnect"
            type="button"
            data-keep-attribute="disabled"
            phx-click={set_action("disconnect")}
          >
            <.remix_icon icon="shut-down-line" />
            <span class="font-medium">Disconnect runtime</span>
          </button>
          <button
            class="text-red-600 menu-item"
            name="close_all"
            type="button"
            data-keep-attribute="disabled"
            phx-click={set_action("close_all")}
          >
            <.remix_icon icon="close-circle-line" />
            <span class="font-medium">Close sessions</span>
          </button>
          <input id="bulk-action-input" class="hidden" type="text" name="action" />
        </:content>
      </.menu>
    </div>
    """
  end

  @impl true
  def handle_event("set_order", %{"order_by" => order_by}, socket) do
    sessions = sort_sessions(socket.assigns.sessions, order_by)
    {:noreply, assign(socket, sessions: sessions, order_by: order_by)}
  end

  def handle_event("fork_session", %{"id" => session_id}, socket) do
    session = Enum.find(socket.assigns.sessions, &(&1.id == session_id))
    %{images_dir: images_dir} = session
    data = Session.get_data(session.pid)
    notebook = Notebook.forked(data.notebook)

    origin =
      if data.file do
        {:file, data.file}
      else
        data.origin
      end

    {:noreply,
     create_session(socket,
       notebook: notebook,
       copy_images_from: images_dir,
       origin: origin
     )}
  end

  def handle_event("disconnect_runtime", %{"id" => session_id}, socket) do
    session = Enum.find(socket.assigns.sessions, &(&1.id == session_id))
    Session.disconnect_runtime(session.pid)
    {:noreply, socket}
  end

  def format_creation_date(created_at) do
    time_words = created_at |> DateTime.to_naive() |> Livebook.Utils.Time.time_ago_in_words()
    time_words <> " ago"
  end

  def toggle_edit(:on) do
    JS.remove_class("hidden", to: "[data-el-bulk-edit-member]")
    |> JS.add_class("hidden", to: "#toggle-edit")
    |> JS.dispatch("lb:session_list:on_selection_change")
    |> sr_message("bulk actions available")
  end

  def toggle_edit(:off) do
    JS.add_class("hidden", to: "[data-el-bulk-edit-member]")
    |> JS.remove_class("hidden", to: "#toggle-edit")
    |> JS.dispatch("lb:uncheck", to: "[name='session_ids[]']")
    |> JS.dispatch("lb:session_list:on_selection_change")
    |> sr_message("bulk actions canceled")
  end

  defp order_by_label("date"), do: "Date"
  defp order_by_label("title"), do: "Title"
  defp order_by_label("memory"), do: "Memory"

  defp order_by_icon("date"), do: "calendar-2-line"
  defp order_by_icon("title"), do: "text"
  defp order_by_icon("memory"), do: "cpu-line"

  defp sort_sessions(sessions, "date") do
    Enum.sort_by(sessions, & &1.created_at, {:desc, DateTime})
  end

  defp sort_sessions(sessions, "title") do
    Enum.sort_by(sessions, fn session ->
      {session.notebook_name, -DateTime.to_unix(session.created_at)}
    end)
  end

  defp sort_sessions(sessions, "memory") do
    Enum.sort_by(sessions, &total_runtime_memory/1, :desc)
  end

  defp total_runtime_memory(%{memory_usage: %{runtime: nil}}), do: 0
  defp total_runtime_memory(%{memory_usage: %{runtime: %{total: total}}}), do: total

  defp select_all() do
    JS.dispatch("lb:check", to: "[name='session_ids[]']")
    |> JS.dispatch("lb:session_list:on_selection_change")
    |> sr_message("all sessions selected")
  end

  defp set_action(action) do
    JS.dispatch("lb:set_value", to: "#bulk-action-input", detail: %{value: action})
    |> JS.dispatch("submit", to: "#bulk-action-form")
  end
end
