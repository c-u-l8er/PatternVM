defmodule ComplexPatternSystem do
  use PatternVM.DSL

  # Define patterns
  singleton :config_manager, %{config: %{max_widgets_per_hour: 100}}

  factory :widget_factory, [:widget, :gadget, :tool]

  # Define the handler functions first
  def json_to_map(json), do: Jason.decode!(json)
  def map_to_json(map), do: Jason.encode!(map)

  def premium_decorator(widget), do: Map.put(widget, :quality, "premium")
  def discount_decorator(widget), do: Map.put(widget, :price, widget.price * 0.8)

  def get_widget(id), do: "Widget data for #{id}"
  def delete_widget(id), do: "Widget #{id} deleted"

  def validation_can_handle(error), do: error.type == :validation
  def validation_handle(error), do: "Validation error: #{error.message}"

  def db_can_handle(error), do: error.type == :database
  def db_handle(error), do: "Database error: #{error.message}"

  def admin_access_rule(context, _args), do: context.role == "admin"

  # Then use MFA references
  adapter :format_adapter, %{
    json_to_map: &ComplexPatternSystem.json_to_map/1,
    map_to_json: &ComplexPatternSystem.map_to_json/1
  }

  decorator :widget_decorator, %{
    premium: &ComplexPatternSystem.premium_decorator/1,
    discount: &ComplexPatternSystem.discount_decorator/1
  }

  proxy :api_proxy, %{
    get_widget: &ComplexPatternSystem.get_widget/1,
    delete_widget: &ComplexPatternSystem.delete_widget/1
  }, %{
    delete_widget: &ComplexPatternSystem.admin_access_rule/2
  }

  chain_of_responsibility :error_handler, [
    %{
      name: :validation_error_handler,
      can_handle: &ComplexPatternSystem.validation_can_handle/1,
      handle: &ComplexPatternSystem.validation_handle/1,
      priority: 10
    },
    %{
      name: :db_error_handler,
      can_handle: &ComplexPatternSystem.db_can_handle/1,
      handle: &ComplexPatternSystem.db_handle/1,
      priority: 5
    }
  ]

  # Define workflows
  workflow :create_widget_structure, sequence([
    # Create catalog items
    create_component(:widget_catalog, "cat1", "Base Widgets", :category),
    create_component(:widget_catalog, "cat2", "Premium Widgets", :category),
    create_component(:widget_catalog, "w1", "Basic Widget", :product, %{price: 50}),
    create_component(:widget_catalog, "w2", "Pro Widget", :product, %{price: 100}),

    # Build catalog structure
    add_child(:widget_catalog, "cat1", "w1"),
    add_child(:widget_catalog, "cat2", "w2"),

    # Apply decorators to a widget
    decorate(:widget_decorator, {:context, :last_result}, [:premium]),

    # Execute a command and then undo it
    execute_command(:widget_commands, :create_widget, %{}),
    undo_command(:widget_commands),

    # Adapt data between formats
    adapt(:format_adapter, %{name: "Widget", id: 123}, :map_to_json),

    # Handle errors with chain of responsibility
    process_request(:error_handler, %{type: :validation, message: "Invalid widget type"})
  ])

  workflow :secure_api_access, sequence([
    # Regular user access - allowed
    proxy_request(:api_proxy, :get_widget, "widget-123", %{role: "user"}),

    # Regular user trying to delete - denied
    proxy_request(:api_proxy, :delete_widget, "widget-123", %{role: "user"}),

    # Admin user delete - allowed
    proxy_request(:api_proxy, :delete_widget, "widget-123", %{role: "admin"})
  ])
end
