---
title: "Real-Time System in Practice (Part 1): Event-Driven Architecture with SignalR"
date: 2026-03-14T22:21:33.291Z
toc: true
categories:
  - Architecture
tags:
  - System Design
  - Real-Time Systems
  - Event-Driven Architecture
  - Scalability
topic: event-driven-realtime-system
---
While developing [AkkaSync](https://github.com/oninebx/AkkaSync), I planned a frontend dashboard to visualize the data synchronization process in real time and surface potential issues as they occur.

As the system runs, it emits events that reflect its current state — milestones that mark its progress. In Akka.NET, these milestones can be published as actor messages, allowing different consumers to react and present the information in dashboards, monitoring tools, or other real-time visualizations.

As AkkaSync evolves, the number of events grows rapidly with each new capability. This makes it important to design the architecture around the Open–Closed Principle so that new capabilities can be added without increasing complexity. In this series, I’ll explore how to design evolving real-time systems in a way that keeps them extensible rather than overwhelming.

Once produced, these events need to be delivered to the frontend in real time. SignalR provides a convenient way to push updates to connected clients, though the architecture itself is not tied to this specific technology.

## Design Challenges
 
In a real-time system, every component poses a challenge. As a project just getting started, the system’s complexity tends to grow rather than converge. This makes scalability and maintainability top priorities in the design process. Below, I’ve highlighted several key areas that proved especially valuable to consider.

### Designing the State Store

#### Redux-Inspired State Management

Observing a real-time system essentially means observing its state at a given moment, with each state evolving in response to events occurring in the system — a pattern that closely resembles **Redux-style** state management in React.

However, the places that display this state, such as a frontend dashboard, operate independently of the system’s lifecycle. Users may open or close the dashboard at any time, and new consumers may join at arbitrary moments. As a result, the system cannot rely solely on live event streams to reconstruct state on demand.

Instead, the current state must be maintained and persisted on the server side, making a centralized state store a natural part of the architecture. The diagram below illustrates a Redux-inspired state store implemented on the backend.

<div class="mermaid">
flowchart LR

    Producer["Event Producers"]

    Event["Events"]

    Reducer["Reducers (state handlers)"]

    subgraph Store["Backend State Store"]
        S1["Pipelines State Slice"]
        S2["Schedules State Slice"]
        S3["Other Domain Slice"]
    end

    Consumer["System Consumers (Dashboard / Monitoring / APIs)"]

    Producer --> Event
    Event --> Reducer

    Reducer -->|update| S1
    Reducer -->|update| S2
    Reducer -->|update| S3

    S1 --> Consumer
    S2 --> Consumer
    S3 --> Consumer
</div>

The **single source of truth** principle in Redux also proved valuable for the backend design. By maintaining the system’s current state in a centralized store, the architecture becomes easier to reason about and evolve.

#### DDD-Inspired Store Organization

Event-driven state transitions are the heartbeat of real-time systems. However, as functionality expands, the explosion of event types can quickly turn a state store into an unmanageable monolith. To counter this, we adopt a DDD-inspired organization that prioritizes high cohesion and low coupling over rigid architectural rules.

Instead of grouping state by technical layers (like "all reducers" or "all models"), we align the store with logical domain boundaries. Each domain acts as an autonomous unit, owning its specific state slices, reducers, and logic.

- **High Cohesion**: By keeping related state and its transition logic within the same domain boundary, we ensure that a single business change only impacts a localized part of the store. This makes the system's behavior predictable and easy to reason about.

- **Low Coupling**: Domains interact through clearly defined events, ensuring that adding a new state slice or refactoring a specific reducer doesn't ripple through unrelated parts of the system.

This approach transforms the store from a "giant bucket of data" into a modular ecosystem. It allows the system to remain lean and maintainable, even as the complexity of events and business requirements continues to scale.

### Designing the Event Mappings

In a real-time system, events emitted by the backend carry the latest facts about the system. These events update the backend state store and must also be communicated to frontend consumers as **messages that update the Redux store**, much like actions carrying payloads.

While it might seem natural to send events directly to the frontend — for example, a PipelineCreated event contains the pipeline ID and start time — this approach has several drawbacks:

1. **Unclear responsibility** – Events originate from the domain or infrastructure layers. Using them directly as frontend messages blurs boundaries and may confuse future developers.

2. **Incomplete or overly fine-grained data** – Events typically carry only the information related to the change itself. Continuing the example, PipelineCreated does not include the end time. Sending the full updated state of relevant objects simplifies consumption and reduces unnecessary complexity.

3. **Need for additional metadata** – Frontend messages often require extra information, such as a message ID or timestamp, which is not included in domain events.

To address these issues, each backend event is mapped to a **frontend message** that encapsulates the relevant state and any additional metadata needed. This design ensures that messages are **clear, complete, and consistent**, while maintaining a clean separation of concerns. Once mapped, these messages are pushed to connected clients using **SignalR**, providing real-time updates to dashboards, monitoring tools, and other consumers. Importantly, the event-to-message mapping logic is **independent of the transport mechanism**, keeping the architecture flexible and decoupled.

The diagram below shows a sample mapping from a backend event to multiple frontend messages.

<div class="mermaid">
flowchart LR
    Event["Backend Event<br/>(e.g., PipelineCreated)"]

    Mapping1["Mapping 1<br/>(Pipeline Slice)"]
    Mapping2["Mapping 2<br/>(Schedules Slice)"]
    Mapping3["Mapping 3<br/>(Other Slice)"]

    Message1["Frontend Message 1"]
    Message2["Frontend Message 2"]
    Message3["Frontend Message 3"]

    Dashboard["Dashboard UI"]
    Monitoring["Monitoring / Alerts"]
    Analytics["Analytics / Reports"]

    Event --> Mapping1
    Event --> Mapping2
    Event --> Mapping3

    Mapping1 --> Message1
    Mapping2 --> Message2
    Mapping3 --> Message3

    Message1 --> Dashboard
    Message2 --> Monitoring
    Message3 --> Analytics

</div>

### Designing the Messaging Infrastructure

One of the key challenges in a real-time system is decoupling the generation of messages from their delivery. On the backend, messages are created by defining events, emitting them, and mapping them into frontend-consumable payloads. The messaging infrastructure is responsible for sending these messages to clients, including tasks such as encapsulation, transport, and deserialization on the frontend.

By separating message generation from message delivery, we can adhere to the Open–Closed Principle: when new types of messages are introduced, the sending logic does not need to be modified. This design makes the system easier to extend and maintain, as adding new message types only requires implementing the mapping, without touching the transport layer.

In practice, this decoupling allows the backend to push updates through SignalR (or any other transport mechanism) without creating tight dependencies between the state store, event mappings, and the delivery mechanism. Each layer — event generation, mapping, and sending — evolves independently while maintaining clear responsibilities.

To simplify the messaging infrastructure, we encapsulate messages in a unified format, called EventNotification, which carries the action and payload needed to update the frontend Redux store.

To separate the actual message content from additional metadata — such as message ID, sequence number, or timestamp — each EventNotification is further wrapped in a unified envelope object, referred to as an EventEnvelope. This design ensures that the delivery layer can handle all messages in a consistent way, while keeping the payload and metadata clearly separated.

The diagram below illustrates the design of the messaging infrastructure, including message encapsulation and parsing.

<div class="mermaid">
flowchart LR
    Notification["EventNotification<br/>(action + payload)"]

    Envelope["EventEnvelope 1<br/>(metadata + notification)"]

    Transport["Messaging Infrastructure<br/>(SignalR / WebSocket / other)"]

    Middleware["Redux Middleware<br/>(parses EventEnvelope → action)"]
    HandlerMap["Handler Map<br/>(dispatches actions to appropriate reducers)"]
    ReduxStore["Frontend Redux Store<br/>(state updated)"]

    Notification --> Envelope

    Envelope --> Transport

    Transport --> Middleware
    Middleware --> HandlerMap
    HandlerMap --> ReduxStore

</div>

To simplify the flow, a Redux middleware is introduced on the frontend as a unified entry point for handling incoming messages. It parses each EventEnvelope into an action, decoupling message interpretation from state updates and allowing reducers to focus solely on updating the state.


## Architectural Overview

Based on the challenges discussed above, I designed and implemented the following architecture to address them effectively. It provides several key advantages:

- **Single source of truth**: A centralized state store ensures all system state is consistently derived from events.

- **Clear separation of concerns**: Event generation, mapping, messaging, and state updates are decoupled.

- **Scalable event handling**: Structured mappings make it easier to manage a growing number of events.

- **Standardized messaging**: A unified message format simplifies both encapsulation and parsing.

- **Frontend-backend alignment**: Adopting a Redux-inspired model keeps state management consistent across the system.

- **Extensibility**: New events or message types can be added without modifying existing infrastructure.

<div class="mermaid">
flowchart TD
    subgraph Backend
        Event["Events"]
        StateStore["State Store<br/>(DDD-style slices)"]
        Mapping["Event Mappings<br/>(to frontend messages)"]
    end

    subgraph Messaging_Infrastructure
        Notification["EventNotification<br/>(action + payload)"]
        Envelope["EventEnvelope<br/>(metadata + notification)"]
        Transport["Transport Layer<br/>(SignalR / WebSocket)"]
    end

    subgraph Frontend
        Middleware["Redux Middleware<br/>(parse EventEnvelope)"]
        HandlerMap["Handler Map<br/>(action → reducers)"]
        Store["Redux Store<br/>(state slices)"]
    end

    Event --> StateStore
    Event --> Mapping

    Mapping --> Notification
    Notification --> Envelope
    Envelope --> Transport

    Transport --> Middleware
    Middleware --> HandlerMap
    HandlerMap --> Store
</div>

## What's Next

This architecture establishes a solid foundation for managing real-time, event-driven state in a scalable and maintainable way. While the overall design is now in place, the frontend messaging infrastructure plays a crucial role in making it work seamlessly in practice.

In the next post, I will explore how raw events are mapped into consistent system state snapshots, focusing on a simple and extensible reducer-based design that evolves with the system.


