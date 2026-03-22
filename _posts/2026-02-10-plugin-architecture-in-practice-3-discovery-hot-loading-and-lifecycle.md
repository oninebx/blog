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

## Two Moments of Hot Loading

In practice, hot loading is not about different mechanisms, but about when the loading occurs.

In this design, plugin instantiation is consistently handled through runtime creation, while hot loading can take place at two distinct moments.

### Startup Phase
The first moment occurs during application startup.

At this stage, the system scans the plugin directory, loads available plugin assemblies, and creates instances dynamically. This phase also handles any pending operations from previous runs, such as cleaning up or replacing plugins that were marked for deletion.

Although this happens during initialization, it still follows the same runtime instantiation model, ensuring consistency with the rest of the system.

### Runtime Phase
The second moment occurs after the application is already running.

When plugin assemblies are added, updated, or removed in the plugin directory, the system reacts dynamically by loading new plugins or disposing of existing ones. Instances are created on demand and integrated into the system without requiring a restart.

This represents true hot loading, where the system remains continuously available while adapting to changes.

### Implementation

In this section, I will walk through the core implementation of hot loading, focusing on the key mechanisms behind plugin loading and unloading.

#### Dynamic Loading via Reflection
I initially registered plugin providers as singleton instances during the service registration phase. However, this approach proved problematic.

Instances held by the DI container cannot be fully unloaded at runtime, introducing unnecessary complexity in lifecycle management.

By contrast, creating plugin instances dynamically via reflection allows references to be released, providing a simpler and more flexible solution for both startup and runtime hot loading.

With this approach, creating plugin provider instances is simplified to the following code:

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

#### Safe Unloading via Pending Delete
In theory, a plugin assembly can be deleted at runtime once all references to its instances are released. In practice, however, it is difficult to precisely control the deletion timing, and even after unloading, the files may still be in use. The **pending delete mechanism** simplifies this process: unloaded plugins are marked as pending delete, no longer used by the system, and their files are safely cleaned up on the next application restart.

To implement this mechanism, I introduced a registry.json file to track plugin package states and a shadow directory to host the loaded plugin assemblies.

***Sample Plugins and Shadow folder***

```text
PluginsRoot/
├── plugins/
│   ├── AkkaSync.Plugins.Transformer.DbTable.zip
│   ├── AkkaSync.Plugins.Source.File.zip
│   ├── AkkaSync.Plugins.HistoryStore.InMemory.zip
│   ├── AkkaSync.Plugins.Sink.Sqlite.zip
│   └── registry.json
└── shadow/
    ├── AkkaSync.Plugins.Transformer.DbTable
        ├── AkkaSync.Plugins.Transformer.DbTable.dll
        ├── ...(dependent files)
        └── manifest.json
    ├── AkkaSync.Plugins.Source.File
    ├── AkkaSync.Plugins.HistoryStore.InMemory
    └── AkkaSync.Plugins.Sink.Sqlite
```


***Sample registry.json***

```json
[
  {
    "Id": "AkkaSync.Plugins.Transformer.DbTable",
    "Version": "1.0.0",
    "PendingDelete": false
  },
  {
    "Id": "AkkaSync.Plugins.Source.File",
    "Version": "1.0.0",
    "PendingDelete": true
  },
  {
    "Id": "AkkaSync.Plugins.HistoryStore.InMemory",
    "Version": "1.0.0",
    "PendingDelete": false
  },
  {
    "Id": "AkkaSync.Plugins.Sink.Sqlite",
    "Version": "1.0.0",
    "PendingDelete": true
  }
]
```

The mechanism works by monitoring the Plugins directory. When a new plugin ZIP file is created, it is extracted into the shadow directory and loaded into the system. When a ZIP file is deleted, the corresponding PluginLoadContext is unloaded, and the pendingDelete flag in registry.json is set to true. The plugin files are then safely removed on the next application restart.

```csharp
...
var fileKey = Path.GetFileName(path);

var entries = await _pluginCatalog.GetAllAsync(p => p.Id == fileKey && p.Version == version);
if (entries != null && entries.Count == 1)
{
  // mark plugin PendingDelete as true in registry.json file
  var entryToUpdate = entries[0];
  await _pluginCatalog.UpdateAsync(entryToUpdate with { PendingDelete = true});
}

if (_pluginContexts.TryGetValue(fileKey, out var context))
{
  // unload the plugin AssemblyLoadContext
  context.Unload();
  _pluginContexts.Remove(fileKey);
  context = null;

  // optional but recommended: Promptly release resources
  GC.Collect();
  GC.WaitForPendingFinalizers();
  GC.Collect();
}
...
```

#### OCP via Adapter Pattern
In implementing hot-pluggable support for multiple plugin types, the code was refactored to follow the Open-Closed Principle, ensuring that the hot-plug management logic remains unchanged when new plugin types are added.
I will not go into further detail here. The core implementation uses the Adapter pattern to unify different generic plugin registries under a common type, greatly simplifying the code. Interested readers can refer to [PluginLoaderActor](https://github.com/oninebx/AkkaSync/blob/main/src/AkkaSync.Infrastructure/PluginLoaderActor.cs) and [PluginProviderRegistryAdapter](https://github.com/oninebx/AkkaSync/blob/main/src/AkkaSync.Core/PluginProviders/PluginProviderRegistryAdapter.cs) for the full implementation.

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