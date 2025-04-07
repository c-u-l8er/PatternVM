# PatternVM

A virtual machine for modeling and executing design patterns from Refactoring Guru in Elixir.

## Description

PatternVM represents design patterns as modular components that can interact in a network. It leverages Elixir's concurrency model and functional paradigm to implement classic design patterns in a new way.

## Features

- Modular implementation of design patterns (Singleton, Factory, Observer, etc.)
- Pattern interaction network
- DSL for defining pattern compositions
- Dynamic pattern loading
- Visualization of pattern networks

## Examples
Demo:

```bash
mix run examples/dsl_example.exs 2>&1 | tee dsl_example.stdout.txt

mix run examples/complex_pattern_system.exs 2>&1 | tee complex_pattern_system.stdout.txt
```

## Installation

Add `pattern_vm` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pattern_vm, "~> 0.1.0"}
  ]
end
```

## Usage

### Basic Usage

```elixir
# Start the application
Application.start(:pattern_vm)

# Create a product using the Factory pattern
product = PatternVM.create_product(:widget)

# Get the Singleton instance
singleton = PatternVM.get_singleton()

# Add an observer for products
PatternVM.add_observer("products")
```

### Using the DSL

```elixir
defmodule MyPatterns do
  use PatternVM.DSL

  # Define patterns
  singleton :config
  factory :product_factory, [:widget, :gadget]
  observer :notifications, ["products"]

  # Define a workflow
  workflow :create_widget, sequence([
    create_product(:product_factory, :widget),
    notify("products", {:context, :last_result})
  ])
end

# Initialize patterns
MyPatterns.execute()

# Run a workflow
PatternVM.DSL.Runtime.execute_workflow(MyPatterns, :create_widget)
```

## Design Patterns

The following design patterns are currently implemented:

- **Singleton**: Ensures a class has only one instance
- **Factory**: Creates objects without specifying their exact types
- **Observer**: Notifies subscribers when state changes
- **Builder**: Constructs complex objects step by step
- **Strategy**: Defines a family of interchangeable algorithms

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
