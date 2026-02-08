---
title: Plugin Architecture in .NET(2) - Contract, Registration, and Resolution
date: 2026-02-06T20:14:47.310Z
toc: true
categories:
  - Architecture
tags:
  - C#
  - .NET
  - System Design
---
In complex software systems, true extensibility doesn’t come from dynamically loading components—it comes from well-defined contracts that establish clear boundaries between responsibilities. A system built around explicit contracts allows new functionality to be added, replaced, or composed without breaking existing behavior.

Systems with these characteristics are ideal for a plugin architecture. In this post, we use AkkaSync as a real-world example to show how plugin contracts—defining responsibilities and boundaries—are implemented, how plugins are composed into ETL pipelines, and how registry and provider patterns organize plugin instances and roles, enabling flexible and maintainable pipelines.

> [AkkaSync](https://github.com/oninebx/AkkaSync) is an actively maintained, plugin-based ETL engine project that I am currently developing.

## Plugin Contract
ETL pipelines are naturally structured around contracts. Each stage — extracting data, transforming it, and saving it — has a clear role and expectations about what goes in and what comes out. These boundaries act like built-in agreements between stages.

Once we formalize those agreements, each stage becomes replaceable and extensible without breaking the overall workflow — which is precisely what a plugin architecture relies on.

Based on these contracts, the ETL pipeline is expressed through three plugin interfaces, each representing a distinct stage:

- **ISyncSource** - Defines how data is extracted from external systems and introduced into the pipeline in a consistent, processable form.

- **ISyncTransformer** - Applies transformation rules to reshape and normalize data as it flows between pipeline stages.

- **ISyncSink** - Specifies how transformed data is reliably persisted to the destination system.

In addition to the primary ETL plugins, auxiliary contracts can assist without changing the main workflow. 

- **IHistoryStore** - Stores the processing state and progress, enabling reliable resumption, auditing, and recovery of the pipeline.

These interfaces act as explicit extension points, allowing the pipeline to be composed from interchangeable plugins.

## Plugin Registration

Plugin contracts define responsibilities, but registration determines how implementations are organized and coordinated at runtime. By registering plugins against their contracts, the system gains a unified way to resolve and use them at runtime, while preserving modularity and replaceability.

The registration model follows a minimal design principle: keep the structure shallow and avoid over-engineering. However, plugin contracts — especially those in an ETL pipeline — impose runtime requirements such as error isolation and independent execution. For this reason, plugins are instantiated per pipeline rather than shared globally.

ETL workloads can be processed in parallel — for example, multiple CSV sources of the same type may run concurrently. This means a single plugin implementation may need multiple active instances at the same time.To support this, each plugin implementation is paired with a factory responsible for creating its instances.The IPluginProvider interface formalizes this factory role, with a dedicated provider implementation for each concrete plugin implementation.

To facilitate this centralized management and provide a consistent access point for all plugin implementations, the system introduces the IPluginProviderRegistry interface. It maps plugin contracts to their providers, enabling uniform resolution while keeping the registration structure simple and modular.

In production systems, plugin instantiation must be carefully governed to avoid resource contention; lifecycle management is important but will not be elaborated on here.

The following class diagram illustrates the registration design, showing how the IPluginProviderRegistry manages providers and how they relate to plugin implementations.

<div class="mermaid">
classDiagram

class IPluginProviderRegistry~T~ {
  +GetProvider(...)
  +AddProvider(...)
  +Count
}

class IPluginProvider~T~ {
  +Key
  +Create(...)
}

class ISyncSource {
  +ReadAsync(...)
}

class ISyncTransformer {
  +Transform(...)
  +Produce
  +DependsOn
}

class ISyncSink {
  +WriteAsync(...)
}

class IHistoryStore {
  +GetAsync(...)
  +UpsertAsync(...)
  +UpdateCursor(...)
  +MarkCompleted(...)
  +MarkRunning(...)
  +MarkFailed(...)
}

IPluginProviderRegistry~T~ --> IPluginProvider~T~ : manages
IPluginProvider~T~ ..> ISyncSource
IPluginProvider~T~ ..> ISyncTransformer
IPluginProvider~T~ ..> ISyncSink
IPluginProvider~T~ ..> IHistoryStore

</div>


- **IPluginProviderRegistry&lt;T&gt;**: Acts as the central coordination layer for plugin providers of type T, maintaining a collection of available providers and offering a unified way to resolve them at runtime. Being a singleton ensures a single source of truth, while the generic type parameter allows plugin categories to be isolated and managed independently.

- **IPluginProvider&lt;T&gt;**: Encapsulates the creation and supply of plugin implementations for a specific contract T. Keeping providers as singletons avoids redundant instantiations and ensures consistent plugin behavior, while generics enable type-safe separation between different plugin kinds (e.g., sources, transformers, sinks, or history stores).

## Plugin Resolution

Plugin resolution defines how plugins are retrieved and instantiated at runtime. By resolving plugins through the registry and their providers, consumers can obtain the required implementations without depending on concrete types.

### Registry Implementation and Setup

PluginProviderRegistry maintains a dictionary of providers keyed by their plugin identifiers. Its constructor accepts an enumerable of providers, enabling initialization via dependency injection, while the AddProvider and GetProvider methods provide a simple, type-safe mechanism to register and resolve plugin implementations at runtime.

```csharp
// PluginProviderRegistry.cs
...
private readonly Dictionary<string, IPluginProvider<T>> _providers;

public PluginProviderRegistry(IEnumerable<IPluginProvider<T>> providers)
{
  _providers = providers.ToDictionary(p => p.Key, p => p);
}

...

public bool AddProvider(IPluginProvider<T> provider) => _providers.TryAdd(provider.Key, provider);

public IPluginProvider<T>? GetProvider(string key)
{
  _ = _providers.TryGetValue(key, out var provider);
  return provider;
}
```

Each plugin category maintains its own provider registry, registered as a singleton in the dependency injection container. The generic registry ensures type isolation between plugin contracts while providing a consistent resolution mechanism. Because the registry only manages provider metadata rather than runtime plugin instances, a singleton lifetime is appropriate.

```csharp
services.AddSingleton<IPluginProviderRegistry<ISyncSource>, PluginProviderRegistry<ISyncSource>>();
services.AddSingleton<IPluginProviderRegistry<ISyncTransformer>, PluginProviderRegistry<ISyncTransformer>>();
services.AddSingleton<IPluginProviderRegistry<ISyncSink>, PluginProviderRegistry<ISyncSink>>();
services.AddSingleton<IPluginProviderRegistry<IHistoryStore>, PluginProviderRegistry<IHistoryStore>>();
```

### Configuration-Driven Resolution

Plugin resolution is a prerequisite for composition, as plugins must be instantiated before they can be assembled according to configuration, avoiding hard-coded dependencies. Configurations can be stored in JSON or YAML files for simplicity and readability, or in structured databases for dynamic and centralized management. Other mechanisms, such as XML, INI/TOML files, or programmatic definitions, are also possible depending on the project requirements.

For example, AkkaSync uses JSON files to define plugin compositions, specifying which sources, transformers, and sinks should be assembled into each pipeline.

```json
 "AkkaSync": {
   "Pipelines":{
     "sync-orders": {
       "Name": "sync-orders",
       "SourceProvider": {
         "Type": "FolderWatcherSourceProvider",
         "Parameters": {
           "folder": "Csv2Sqlite/input/orders",
           "source": "csv"
         }
       },
       "TransformerProvider": {
         "Type": "TableTransformerProvider",
         "Parameters": {
           "transformers": "pipelines/plugin_transformers_order.json"
         }
       },
       "SinkProvider": {
         "Type": "SqliteSinkProvider",
         "Parameters": {
           "connectionString": "Data Source=Csv2Sqlite/output/orderstore.db;Mode=ReadWriteCreate;Cache=Shared;Pooling=True;Foreign Keys=True;",
           "batchSize": 50
         }
       },
       "HistoryStoreProvider": {
         "Type": "InMemoryHistoryStoreProvider",
         "Parameters": {
           "name": "demo"
         }
       }
     }
   },
```

 JSON configuration files are parsed into strongly-typed objects and registered as singletons for runtime use.

```csharp
...
var pipelineOptions = mergedConfig.GetSection("AkkaSync").Get<PipelineOptions>()!;
services.AddSingleton(pipelineOptions);
...
```

> The details of configuring pipelines in [AkkaSync](https://github.com/oninebx/AkkaSync) are documented elsewhere and will not be repeated here.

Using IPluginProviderRegistry is straightforward: consumers inject the registry via the constructor, locate the appropriate plugin providers based on configuration, and obtain plugin instances from each provider for use in the pipeline.

```csharp
// PipelineRegistryActor.cs
...
 public PipelineRegistryActor(
   IPluginProviderRegistry<ISyncSource> sourceRegistry, 
   IPluginProviderRegistry<ISyncTransformer> transformerRegistry, 
   IPluginProviderRegistry<ISyncSink> sinkRegistry,
   IPluginProviderRegistry<IHistoryStore> storeRegistry,
   PipelineOptions options)
 {
   _sourceRegistry = sourceRegistry;
   _transformerRegistry = transformerRegistry;
   _sinkRegistry = sinkRegistry;
   _storeRegistry = storeRegistry;
   _pipelineSpecs = options.Pipelines!; // Parsed from JSON file.
   ...
 }
...
if(_pipelineSpecs.TryGetValue(msg.Name, out var spec) is false)
{
  _logger.Warning($"Pipeline spec with name {msg.Name} not found.");

  ...
}
...
var source = spec.SourceProvider;
var sourceProvider = _sourceRegistry.GetProvider(source.Type);

var transformer = spec.TransformerProvider;
var transformerChain = _transformerRegistry.GetProvider(transformer.Type);

var sink = spec.SinkProvider;
var sinkProvider = _sinkRegistry.GetProvider(sink.Type);

var store = spec.HistoryStoreProvider;
var storeProvider = _storeRegistry.GetProvider(store?.Type ?? string.Empty);
...
```

The assembly of plugins is application-specific and will not be detailed here; for further information, please refer to the [AkkaSync Repository](https://github.com/oninebx/AkkaSync)

## Conclusion and Next Steps

In this article, we explored the design of AkkaSync's plugin infrastructure, covering plugin contracts, registry implementation, and configuration-driven resolution. We examined how contracts define responsibilities, how registries manage providers, and how runtime resolution enables flexible, type-safe, and modular pipelines.

In the next installment, we will focus on plugin discovery and hot-swapping, showing how plugins can be dynamically loaded, replaced, or updated at runtime without restarting the system, further enhancing the flexibility and extensibility of AkkaSync.



