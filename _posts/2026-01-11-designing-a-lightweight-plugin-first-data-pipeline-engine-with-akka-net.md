---
title: Designing a Lightweight, Plugin-First Data Pipeline Engine with Akka.NET
date: 2026-01-11T08:24:47.570Z
toc: true
categories:
  - Project Notes
tags:
  - C#
  - .NET
  - TypeScript
  - Next.js
  - System Design
---

## Data Synchronization Everywhere
Data synchronization between business systems is extremely common in real-world software projects. As organizations grow, data no longer lives in a single system, turning consistency and timely data propagation into an ongoing engineering concern.

In projects I’ve been involved in, data synchronization has been a recurring practical necessity. This ranges from synchronizing employee and organizational data from OA systems for authorization and identity management, to batch-oriented scenarios such as monthly imports of bank reconciliation CSV files. In more complex domains like healthcare, data synchronization is often a prerequisite for compliant data usage: only carefully selected subsets of PMS data are synchronized into a portal application, where they are replicated into both SQL Server and Elasticsearch to simplify system design and enable efficient, compliant querying.

Across multiple projects, data synchronization repeatedly surfaced as a cross-cutting concern. Instead of addressing it through ad-hoc, project-specific solutions, I began designing a lightweight and flexible synchronization engine. It provides a configurable, observable, and extensible foundation for building business-specific workflows, while avoiding the complexity and cost of full-scale ETL platforms. The architecture is intentionally open, enabling customization where domain logic is required, yet keeping the core simple and focused.

## Motivation and Design Goals
Akka.NET actors are isolated, stateful, and message-driven, and are organized under supervisors that monitor and manage failures. This provides **concurrency, fault tolerance, and predictable recovery**, making actors ideal for building reliable and observable data synchronization workflows.

### Concurrency model in Data Synchronization
Data synchronization workflows can be modeled as a set of **pipelines**, where each pipeline represents a distinct category of data or synchronization use case. Different data types often follow different rules, schedules, and destinations, making this separation both natural and practical.

Within each pipeline, multiple **workers** process the same type of data from different sources or partitions. This structure enables parallel execution while keeping responsibilities clear: pipelines define _what_ is synchronized, and workers define _how_ the workload is parallelized.

### Plugin-Based Pipelines and Workers for ETL
In the context of pipelines and workers, **ETL** refers to the classic **Extract, Transform, Load** process:

- **Extract**: Workers pull data from various sources, such as files, databases, or APIs.
- **Transform**: Plugins apply business rules, validations, or data transformations to the extracted data.
- **Load**: Processed data is persisted into the target system, such as SQL or NoSQL databases.

![etl architecture]({{ "uploads/akkasync-introduction-etl.png" | relative_url }})

Each pipeline represents a **distinct category of data**, and its workers handle data from multiple sources or partitions. The ETL process is executed within each worker using a **plugin-based design**, which makes the workflow modular, reusable, and easy to extend.
By separating **workflow orchestration (Pipeline)** from **execution (Worker)** and **processing logic (Plugin)**, this ETL model allows concurrent, traceable, and maintainable data synchronization across diverse sources and destinations.

In addition to extract, transform, and load plugins, the pipeline also supports state persistence with a **HistoryStore plugin**.
This plugin is responsible for **persisting ETL execution state**, such as cursors, offsets, checkpoints, or watermarks, during data synchronization.
Typical use cases include:

- Recording the last processed timestamp or ID
- Persisting file offsets or row numbers
- Supporting incremental and resumable synchronization
- Enabling safe retries and recovery after failures

This makes ETL workflows **stateful, resumable, and fault-tolerant**, without coupling state management to business logic.

### Monitoring and Scheduling Pipelines
In projects I’ve worked on, **data synchronization** was typically monitored by **manually analyzing logs**.
While effective for debugging, this approach does not scale well: logs are fragmented, hard to correlate across concurrent workers, and heavily reliant on human interpretation.

To address this, **observability** was considered a core design concern. Synchronization progress and execution states are tracked in a structured and visualized way, reducing reliance on log inspection and making pipelines easier to monitor and operate.

The engine introduces a set of synchronization-specific events (**SyncEvents**) to make pipeline execution observable. These events represent meaningful lifecycle changes and progress updates, and are streamed to the frontend in real time via **SignalR**. By exposing structured execution signals instead of raw logs, synchronization workflows become easier to monitor, track, and reason about.

Another key feature is **pipeline scheduling**, designed to free business users from repetitive and manual execution — I’ve received far too many complaints about this kind of repetitive work. Each pipeline declares its own schedule using cron expressions, allowing the engine to **autonomously execute synchronization tasks**. Combined with real-time monitoring, this makes pipeline runs both self-managed and visually observable.

## MVP: CSV to SQLite
I’ve built an MVP with plugin-based pipelines and workers, autonomous scheduling, and real-time monitoring. Inspired by real-world scenarios like transforming CSV files into business system databases, it already puts these design principles into practice, and I plan to develop more plugins to support additional use cases as the system evolves.

Beyond CSV-to-SQLite synchronization, it also supports a wide range of features aligned with its core design principles, including flexible pipeline configuration, an extensible plugin architecture, and a SignalR-based real-time communication protocol with event mapping and processing architecture.

![etl architecture]({{ "uploads/akkasync-introduction-dashboard.png" | relative_url }})

[https://github.com/oninebx/AkkaSync](https://github.com/oninebx/AkkaSync)