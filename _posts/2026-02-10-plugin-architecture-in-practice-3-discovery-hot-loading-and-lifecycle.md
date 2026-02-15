---
title: Plugin Architecture in Practice(Part 3) — Discovery, Hot Loading, and Lifecycle
date: 2026-02-10T23:45:58.547Z
toc: true
categories:
  - Architecture
tags:
  - C#
  - .NET
  - System Design
topic: plugin-engineering
---
Once the plugin contract is defined, development can proceed in parallel — but the system still needs a unified way to discover and manage them. Hot swapping is one of the most powerful advantages of a plugin architecture, allowing system capabilities to evolve at runtime — which makes lifecycle management critical.

## Discovery
Plugins are typically packaged as DLLs built from class library projects. The compiled assemblies are placed in a designated directory, where the host application scans and loads them in a centralized discovery process.


Plugins are loaded into memory via AssemblyLoadContext, and reflection is used at runtime to identify types that implement known plugin interfaces, enabling dynamic discovery. Plugins can be loaded using the default AssemblyLoadContext or a dedicated context per plugin. The trade-offs will be discussed in the hot swapping section. In AkkaSync, each plugin is loaded into its own AssemblyLoadContext for isolation and unloadability. Below is the main code snippet for plugin discovery（specifically, the implementations of IPluginProvider&lt;T&gt; described in Part 2).

```csharp
...
// Supported Plugin types 
private static readonly Type[] SupportedPluginInterfaces =
[
  typeof(IPluginProvider<ISyncSource>),
  typeof(IPluginProvider<ISyncTransformer>),
  typeof(IPluginProvider<ISyncSink>),
  typeof(IPluginProvider<IHistoryStore>)
];

...

// Custom AssemblyLoadContext; each plugin DLL is loaded into its own context
var context = new PluginLoadContext(filePath); 
var assembly = context.LoadPlugin();

var pluginTypes = assembly.GetTypes()
    .Where(t => !t.IsAbstract && !t.IsInterface &&
                SupportedPluginInterfaces.Any(iface => iface.IsAssignableFrom(t)))
    .ToArray();
...
```
The discovered pluginTypes will be used to instantiate plugin instances through service registration or runtime instantiation.

## Two Approaches to Hot Loading

In practice, plugins can be loaded by the host process at two distinct moments. 
The first occurs during application startup. The host scans the plugin directory and registers discovered providers into the dependency injection container as part of system initialization.This resembles a conventional boot-time loading phase, where plugins become available alongside other core services.
The second occurs after the host is already running. When plugin DLLs are added, removed, or replaced in the plugin directory, the system reacts dynamically. This represents true hot loading: plugin instances are created at runtime and added to the existing plugin instance container without restarting the host.

### Service Registration
Service Registration is known as Interface-to-Implementation Registration and occurs during the host’s service registration phase. Discovered plugin interfaces and their corresponding implementations are registered into the container, typically using reflection to map interfaces to their concrete types. The following snippet shows the core implementation:

```csharp
...
foreach (var type in types)
{
  var interfaces = type.GetInterfaces()
                      .Where(i => i.IsGenericType
                      && i.GetGenericTypeDefinition() == typeof(IPluginProvider<>));
  foreach (var iface in interfaces)
  {
    Services.AddSingleton(iface, type);
  }
}
...
```

### Runtime Instantiation
Runtime Instantiation is necessary because service registration resolves dependencies at construction time, producing a fixed snapshot that does not automatically update when new components are introduced at runtime. To support dynamic loading, instances must be created directly while still honoring dependency injection, rather than relying on container registration. This is achieved through a **DI-aware runtime instantiation mechanism**, which ensures that all required dependencies are correctly injected while allowing objects to be constructed on demand. By leveraging this approach, dynamically loaded components can be integrated immediately into the system without modifying the container or violating its lifecycle constraints.

The above design is implemented using ActivatorUtilities, and the core code is as follows:

```csharp
...
foreach (var type in pluginTypes)
{
  var interfaces = type.GetInterfaces()
      .Where(i => i.IsGenericType &&
                  i.GetGenericTypeDefinition() == typeof(IPluginProvider<>));

  foreach (var iface in interfaces)
  {
    var instance = ActivatorUtilities.CreateInstance(serviceProvider, type);
    ...
  }
}
...

```

#### OCP via Adapter Pattern
In implementing hot-pluggable support for multiple plugin types, the code was refactored to follow the Open-Closed Principle, ensuring that the hot-plug management logic remains unchanged when new plugin types are added.
I will not go into further detail here. The core implementation uses the Adapter pattern to unify different generic plugin registries under a common type, greatly simplifying the code. Interested readers can refer to [PluginManagerActor](https://github.com/oninebx/AkkaSync/blob/main/src/AkkaSync.Infrastructure/PluginManagerActor.cs) and [PluginProviderRegistryAdapter](https://github.com/oninebx/AkkaSync/blob/main/src/AkkaSync.Core/PluginProviders/PluginProviderRegistryAdapter.cs) for the full implementation.

Let’s quickly compare the two.

Smelly code
```csharp
...

foreach (var provider in providers)
{
  switch (provider.InterfaceType)
  {
    case Type t when typeof(IPluginProvider<ISyncSource>).IsAssignableFrom(t):
      _sourceRegistry.AddProvider((IPluginProvider<ISyncSource>)provider.ProviderInstance);
      break;
    case Type t when typeof(IPluginProvider<ISyncTransformer>).IsAssignableFrom(t):
      _transformerRegistry.AddProvider((IPluginProvider<ISyncTransformer>)provider.ProviderInstance);
      break;
    case Type t when typeof(IPluginProvider<ISyncSink>).IsAssignableFrom(t):
      _sinkRegistry.AddProvider((IPluginProvider<ISyncSink>)provider.ProviderInstance);
      break;
    case Type t when typeof(IPluginProvider<IHistoryStore>).IsAssignableFrom(t):
     _historyRegistry.Add((IPluginProvider<IHistoryStore>)provider.ProviderInstance);
     break;
     // coding here when new plugin type comes
     ...
  }
}
...
```

Clean code
```csharp
...
foreach (var provider in providers)
{
  var adapter = _registryAdapters.FirstOrDefault(r => r.CanHandle(provider.InterfaceType));
  if (adapter != null)
  {
    adapter.AddProvider(provider.ProviderInstance);
    _logger.Info("PluginProvider {0} is added to registry.", provider.InterfaceType.Name);
  }
}
...
```

## Key Points on Plugin Lifecycles
So far, we have introduced PluginRegistry, PluginProvider, Plugin (see Part 2), and the PluginProviderRegistryAdapter. In a hot-pluggable system, it is essential to clearly manage the lifecycles of dynamically loaded objects to ensure consistency and safe runtime integration.

### Host-Lifetime Singletons
In [Part 2]({% post_url 2026-02-06-plugin-architecture-in-practice-2-contract-registration-and-Resolution %}), we noted that Registry is registered as a singleton at build time, giving it a lifecycle that matches the host process. Each Provider managed by the registry is also a singleton, but instances are created and added to the registry at runtime. This design is straightforward, as the registry serves as the single source of providers, which in turn act as factories for creating plugins.

Each PluginProviderRegistryAdapter corresponds to a single registry, sharing its lifecycle. Like the registry, it is registered as a singleton at build time.

```csharp
...
services.AddSingleton<IPluginProviderRegistryAdapter, PluginProviderRegistryAdapter<ISyncSource>>();
services.AddSingleton<IPluginProviderRegistryAdapter, PluginProviderRegistryAdapter<ISyncTransformer>>();
services.AddSingleton<IPluginProviderRegistryAdapter, PluginProviderRegistryAdapter<ISyncSink>>();
services.AddSingleton<IPluginProviderRegistryAdapter, PluginProviderRegistryAdapter<IHistoryStore>>();
...
```
### Sync-Scoped Instances
Sync-related plugins — ISyncSource, ISyncTransformer, and ISyncSink — follow a pipeline-scoped lifecycle, existing for the duration of the pipeline’s execution. Because AkkaSync supports parallel processing of multiple data sources, each pipeline creates its own plugin instances to ensure execution isolation and safe concurrency.

Within a pipeline, ISyncSource plugins may have multiple instances to handle concurrent sources, whereas ISyncTransformer and ISyncSink instances are shared across all workers. These shared plugins are implemented as pure, stateless classes, making them inherently thread-safe for concurrent use.

IHistoryStore instances are slightly more complex: they are lazily initialized when a pipeline first runs and persist for the lifetime of the host process. The design allows multiple instances, each managing the state and history of one or more pipelines. For simplicity, their lifecycle can be considered aligned with the host process, continuously providing pipeline synchronization history and state to other modules.

| Plugin Type        | Lifecycle              | Instance Strategy                         | Concurrency / Thread Safety               | Shared Across Workers?                  |
|-------------------|----------------------|-------------------------------------------|------------------------------------------|----------------------------------------|
| ISyncSource        | Pipeline-scoped       | One or more instances per pipeline        | Each worker has its own instance → safe  | No                                     |
| ISyncTransformer   | Pipeline-scoped       | Single instance per pipeline              | Pure, stateless → inherently thread-safe | Yes                                    |
| ISyncSink          | Pipeline-scoped       | Single instance per pipeline              | Pure, stateless → inherently thread-safe | Yes                                    |
| IHistoryStore      | Host-process-scoped   | Lazily initialized; multiple instances allowed | Stateless design, manages pipeline state safely | Can be shared across pipelines         |

## Summary and Next Steps

In this chapter, we have essentially completed the discussion on the design and practical development of AkkaSync’s plugin architecture. There may be a follow-up article exploring practical aspects of plugin development, such as testing, release, and version management, to provide more structured and controllable practices.


