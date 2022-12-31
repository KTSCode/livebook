defmodule LivebookWeb.LearnLive do
  use LivebookWeb, :live_view

  import LivebookWeb.SessionHelpers

  alias LivebookWeb.{LayoutHelpers, LearnHelpers, PageHelpers}
  alias Livebook.Notebook.Learn

  on_mount LivebookWeb.SidebarHook

  @impl true
  def mount(_params, _session, socket) do
    [lead_notebook_info | notebook_infos] = Learn.visible_notebook_infos()

    {:ok,
     assign(socket,
       lead_notebook_info: lead_notebook_info,
       notebook_infos: notebook_infos,
       page_title: "Livebook - Learn"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <LayoutHelpers.layout
      socket={@socket}
      current_page={Routes.learn_path(@socket, :page)}
      current_user={@current_user}
      saved_hubs={@saved_hubs}
    >
      <div class="p-4 mx-auto md:px-12 md:py-7 max-w-screen-lg space-y-4">
        <div>
          <PageHelpers.title text="Learn" />
          <p class="mt-4 mb-8 text-gray-700 dark:text-gray-200">
            Check out a number of examples showcasing various parts of the Elixir ecosystem.<br />
            Click on any notebook you like and start playing around with it!
          </p>
        </div>
        <div
          id="welcome-to-livebook"
          class="flex flex-col items-center p-8 bg-gray-900 rounded-2xl sm:flex-row space-y-8 sm:space-y-0 space-x-0 sm:space-x-8"
        >
          <img
            src={Routes.static_path(@socket, @lead_notebook_info.details.cover_url)}
            width="100"
            alt="livebook"
          />
          <div>
            <h3 class="text-xl font-semibold text-gray-50">
              <%= @lead_notebook_info.title %>
            </h3>
            <p class="mt-2 text-sm text-gray-300">
              <%= @lead_notebook_info.details.description %>
            </p>
            <div class="mt-4">
              <%= live_patch("Open notebook",
                to: Routes.learn_path(@socket, :notebook, @lead_notebook_info.slug),
                class: "button-base button-blue"
              ) %>
            </div>
          </div>
        </div>
        <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-1 lg:grid-cols-2 xl:grid-cols-3 gap-4">
          <% # Note: it's fine to use stateless components in this comprehension,
          # because @notebook_infos never change %>
          <%= for info <- @notebook_infos do %>
            <LearnHelpers.notebook_card notebook_info={info} socket={@socket} />
          <% end %>
        </div>
        <%= for group_info <- Learn.group_infos() do %>
          <.notebook_group group_info={group_info} socket={@socket} />
        <% end %>
      </div>
    </LayoutHelpers.layout>
    """
  end

  defp notebook_group(assigns) do
    ~H"""
    <div>
      <div class="flex flex-col items-center p-8 mt-16 border border-gray-300 rounded-2xl sm:flex-row space-y-8 sm:space-y-0 space-x-0 sm:space-x-8">
        <img src={Routes.static_path(@socket, @group_info.cover_url)} width="100" />
        <div>
          <div class="inline-flex px-2 py-0.5 bg-gray-200 rounded-3xl text-gray-700 text-xs font-medium dark:bg-gray-700 dark:text-gray-200">
            <%= length(@group_info.notebook_infos) %> notebooks
          </div>
          <h3 class="mt-1 text-xl font-semibold text-gray-800 dark:text-gray-100">
            <%= @group_info.title %>
          </h3>
          <p class="mt-2 text-gray-700 dark:text-gray-200">
            <%= @group_info.description %>
          </p>
        </div>
      </div>
      <div class="mt-4">
        <ul>
          <%= for {notebook_info, number} <- Enum.with_index(@group_info.notebook_infos, 1) do %>
            <li class="flex flex-row items-center py-4 border-b border-gray-200 space-x-5 last:border-b-0">
              <div class="text-lg font-semibold text-gray-400 dark:text-gray-500">
                <%= number |> Integer.to_string() |> String.pad_leading(2, "0") %>
              </div>
              <div class="font-semibold text-gray-800 grow dark:text-gray-100">
                <%= notebook_info.title %>
              </div>
              <%= live_redirect to: Routes.learn_path(@socket, :notebook, notebook_info.slug),
                    class: "button-base button-outlined-gray" do %>
                <.remix_icon icon="play-circle-line" class="mr-1 align-middle" /> Open
              <% end %>
            </li>
          <% end %>
        </ul>
      </div>
    </div>
    """
  end

  @impl true
  def handle_params(%{"slug" => "new"}, _url, socket) do
    {:noreply, create_session(socket)}
  end

  def handle_params(%{"slug" => slug}, _url, socket) do
    {notebook, images} = Learn.notebook_by_slug!(slug)
    {:noreply, create_session(socket, notebook: notebook, images: images)}
  end

  def handle_params(_params, _url, socket), do: {:noreply, socket}
end
