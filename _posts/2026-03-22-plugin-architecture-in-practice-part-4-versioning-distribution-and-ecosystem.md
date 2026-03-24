---
title: Plugin Architecture in Practice(Part 4) — Versioning, Distribution, and
  Ecosystem
date: 2026-03-22T07:03:08.457Z
toc: true
categories:
  - Architecture
tags:
  - .NET
  - System Design
  - C#
topic: plugin-engineering
---
In the previous three parts, we explored the motivation behind building a plugin system, its structural composition, and the runtime model for loading and execution.

As the final installment of this series, this article shifts the focus from architecture to ecosystem—discussing how to evolve a plugin system into a living and sustainable ecosystem-driven platform through versioning, distribution.

## Ecosystem Overview

The purpose of designing this plugin ecosystem is to provide a clear, maintainable, and scalable structure for managing plugins. It ensures that plugins can be easily distributed, updated, and consumed while maintaining system stability and consistency.

![plugin-ecosystem]({{ "uploads/plugin-ecosystem.png" | relative_url }})

- **Plugin Registry(Online Plugin Repository)**: A centralized location for storing and managing plugins. It contains plugin packages and the remote manifest. The Console checks for updates and downloads plugins from here.

- **Local Plugin Store**: A local collection of installed plugins and the local manifest (registry.json). The Runtime loads plugins from here and uses them to create plugin instances.

- **Runtime Environment**: The environment responsible for loading plugins from the Local Plugin Store and providing plugin instances to Consumers. The Runtime only relies on the local store and does not access the Online Registry directly, ensuring stability.

- **Consumers**: Plugin users or application components that obtain plugin instances through the Runtime. Consumers do not need to manage plugin sources or versions; all details are handled by the Runtime and Local Plugin Store.

To simplify plugin management, I developed a simple Plugin Console, which will not be described in detail here.

## Plugins Versioning

A key strength of the plugin system lies in the strict decoupling between consumers and plugin versions.

Interaction is governed by a stable contract defined at the consumer boundary, enabling independent evolution of plugins without impacting existing integrations. Compared to plugin consumers, versioning on the plugin side is inherently more complex. This complexity arises from the diversity of plugin types and the open development model, where multiple contributors can evolve plugins independently and concurrently.

This complexity is an inherent part of building a plugin ecosystem and cannot be avoided.

In AkkaSync, versioning is intentionally simplified to address two core concerns:

- Compatibility between multiple plugin versions
- Detection and controlled updates of plugin versions

All practices discussed in this article are derived from the [AkkaSync](https://github.com/oninebx/AkkaSync) project.


### Plugin Compatibility
Ideally, a plugin system offers full flexibility—allowing any plugin version to be loaded and freely selected by consumers.

In practice, such flexibility comes at the cost of significant complexity, which is often not justified. To achieve a pragmatic balance between flexibility and complexity, the following strategies are adopted.

- **Single Version per Plugin**: At runtime, only one version of a given plugin can be loaded. Plugins with the same identity—defined by their fully qualified name and SHA hash—cannot coexist.

- **Allow Multiple Distinct Plugins**: Plugins providing similar or overlapping functionality are allowed to coexist, as long as they have different fully qualified names. All plugin names must follow the `akkasync.plugins.*.*` naming convention.

This strategy greatly simplifies plugin version management while maintaining openness to plugin diversity.

### Two-Level Plugin Store Design

A fundamental principle in plugin system design is the separation of version publishing from version usage.

This necessitates a two-level plugin store:

- **Remote Registry**: the central, authoritative repository of all published plugin versions.
- **Local Store**: a local cache that enables offline execution and runtime consumption of plugins.

In a plugin ecosystem, the runtime plays a central role in orchestrating the various components.

Beyond simply loading and unloading plugins or creating plugin instances, it is also responsible for managing versions, ensuring compatibility, and coordinating between the remote registry and local store.

Beyond simply loading and unloading plugins or creating plugin instances, it is also responsible for managing versions, ensuring compatibility, and coordinating between the remote registry and local store.

Version management, in particular, is primarily realized through the manifests maintained at both levels of the plugin store, specifically via the `registry.json` files.

Version upgrades are achieved by comparing the remote and local registry.json manifests. The remote registry is immutable once published alongside a plugin, ensuring a stable source of truth, while the local registry is updated only after the corresponding plugin has been successfully updated locally. This approach enforces safe and controlled version transitions between the remote and local stores.

## Plugins Distribution

In this context, distribution refers to building a remote plugin repository, for which I leveraged GitHub's free services to set up a simple remote plugin store.

### Publish Package via Github Release

To distribute plugins via GitHub Releases, I separated the plugin projects from the AkkaSync repository into an independent repository, allowing the main project and plugins to be released independently.

Plugin releases are automated through a GitHub Actions workflow that packages the plugin as a ZIP, computes its SHA, and publishes it. The workflow is triggered by Git tags. For details, see the workflow file [release.yml](https://github.com/oninebx/AkkaSync.Plugins/blob/main/.github/workflows/release.yml).

To make the system more flexible and open, support for multiple plugin repositories has been implemented. The runtime can then check for plugins from several sources through configuration. To facilitate plugin package management, I implemented a [PluginPackageManager](https://github.com/oninebx/AkkaSync/tree/main/src/AkkaSync.Infrastructure/SyncPlugins/PackageManager), which is currently invoked by the runtime. In the future, exposing it via a **CLI** could also be a viable option.

### Publish Manifest via Github Pages

Initially, the manifest (registry.json) was published together with the plugin packages. This approach proved cumbersome, particularly because the manifest URL changed with every release.

Therefore, separating plugin releases from the registry.json manifest is essential. GitHub Pages offers a static hosting service with built-in CDN, improving availability, stability, and reducing latency. It can also serve as part of the plugin ecosystem, hosting the manifest and providing an official site for the project.

Both updates to the registry.json and the publication of content on GitHub Pages are fully automated via GitHub Actions, triggered by Git tags. The manifest URL is now stable and automatically reflects new plugin releases.

Through the engineering practices described above, I now have an official [AkkaSync website](https://akkasync.github.io/) along with a stable [plugin manifest](https://akkasync.github.io/plugins/registry.json) URL.

![plugin-website]({{ "uploads/plugin-github-pages.png" | relative_url }})

## Conclusion

As the final installment in the Plugin Architecture in Practice series, this article showcases AkkaSync’s plugin ecosystem. By separating plugin releases from the manifest, using a two-level plugin store, and automating publishing via GitHub Actions, the system achieves stability and flexibility. The runtime handles multiple plugin sources, while GitHub Pages provides a reliable host for the manifest and serves as the official site. This practical approach demonstrates how to build a maintainable, extensible plugin architecture that balances version control, distribution, and operational efficiency.