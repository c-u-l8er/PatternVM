defmodule PatternVM.DSL.CombinedPatternsTest do
  use ExUnit.Case

  setup do
    # Ensure PatternVM is started
    if !Process.whereis(PatternVM) do
      PatternVM.start_link([])
    end

    :ok
  end

  test "combining multiple patterns in a workflow" do
    defmodule CombinedExample do
      use PatternVM.DSL

      # Define various patterns
      factory(:product_factory)

      adapter(:format_adapter, %{
        to_json: fn product ->
          "{\"id\":\"#{product.id}\",\"type\":\"#{product.type}\"}"
        end
      })

      decorator(:product_decorator, %{
        premium: fn product -> Map.put(product, :quality, "premium") end,
        discount: fn product ->
          Map.update(product, :price, 100, fn price -> price * 0.9 end)
        end
      })

      observer(:notification_observer, ["product_events"])

      # Define complex workflow combining multiple patterns
      workflow(
        :premium_product_flow,
        sequence([
          # Create a product
          create_product(:product_factory, :widget),
          {:store, :basic_product, :last_result},

          # Add price
          {:transform, :with_price, fn product -> Map.put(product, :price, 100) end},

          # Decorate the product
          decorate(:product_decorator, {:context, :with_price}, [:premium, :discount]),
          {:store, :decorated_product, :last_result},

          # Convert to JSON
          adapt(:format_adapter, {:context, :decorated_product}, :to_json),
          {:store, :json_product, :last_result},

          # Notify about product creation
          notify("product_events", %{
            action: :created,
            product_id: {:context, :basic_product, :id},
            premium: true
          })
        ])
      )
    end

    # Execute definition
    CombinedExample.execute()

    # Run the workflow
    result = PatternVM.DSL.Runtime.execute_workflow(CombinedExample, :premium_product_flow)

    # Check all the intermediate results
    assert result.basic_product.type == :widget
    assert result.decorated_product.quality == "premium"
    # 100 * 0.9
    assert result.decorated_product.price == 90.0
    assert is_binary(result.json_product)
  end

  test "complex interaction between patterns" do
    defmodule ComplexInteractionExample do
      use PatternVM.DSL

      # Define patterns
      singleton(:config, %{instance: %{api_url: "https://api.example.com", timeout: 5000}})
      factory(:request_factory)
      proxy(:api_proxy)
      command(:request_commands)

      # Define workflow with complex interactions
      workflow(
        :api_request_flow,
        sequence([
          # Get configuration
          {:interact, :config, :get_instance, %{}},
          {:store, :config, :last_result},

          # Create a request object
          create_product(:request_factory, :api_request),
          {:transform, :configured_request,
           fn req ->
             Map.merge(req, %{
               url: {:context, :config, :api_url},
               timeout: {:context, :config, :timeout}
             })
           end},

          # Register service in proxy
          {:interact, :api_proxy, :register_service,
           %{
             name: :send_request,
             handler: fn req ->
               %{
                 id: req.id,
                 status: 200,
                 response: %{success: true, data: "Response data"}
               }
             end
           }},

          # Register command
          {:interact, :request_commands, :register_command,
           %{
             name: :execute_request,
             execute_fn: fn req ->
               # Use proxy to send request
               PatternVM.interact(:api_proxy, :request, %{
                 service: :send_request,
                 args: req,
                 context: %{authorized: true}
               })
             end,
             undo_fn: fn _ -> %{cancelled: true} end
           }},

          # Execute the request via command
          execute_command(:request_commands, :execute_request, {:context, :configured_request})
        ])
      )
    end

    # Execute definition
    ComplexInteractionExample.execute()

    # Run the complex workflow
    result = PatternVM.DSL.Runtime.execute_workflow(ComplexInteractionExample, :api_request_flow)

    # Check the final result
    assert result.last_result.status == 200
    assert result.last_result.response.success == true
  end
end
