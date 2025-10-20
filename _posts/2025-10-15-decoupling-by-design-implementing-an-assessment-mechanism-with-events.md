---
title: "Decoupling by Design: Implementing an Assessment Mechanism with Events"
date: 2025-10-15T07:32:04.254Z
toc: true
categories:
  - Project Notes
tags:
  - C#
  - .NET
---
This was my latest practical experience in a real-world project, where I addressed several key challenges in implementing the payee compliance assessment flow.

* clear but general idea: automatically identifying potentially non-compliant payees through a set of rules
* Multiple, distributed rules: non-compliance can arise from rules across processes or domains, which can be freely added or removed.
* Unstable scoring and risk levels: rules are individually scored, and total scores determine risk, with some scoring criteria still undefined.

This is a typical scenario requiring agile development: we need to design a stable structure that can flexibly handle uncertainty, and implement a design that follows OCP and SRP principles. For ease of description, I will refer to this design as the **Assessment Mechanism**. The "Rules" mentioned above will be defined as "**Rubrics**".

## OCP & SRP

**The Open/Closed Principle (OCP)** means that a system should be **open for extension but closed for modification**. In practice, this means we can add new features or behaviors by extending existing code—such as adding new classes, events, or handlers—without changing the stable core logic. This reduces the risk of breaking existing functionality and makes the system easier to evolve.

**The Single Responsibility Principle (SRP)** means that each class or module should have only one clear purpose or reason to change. In practice, this means every component focuses on a single responsibility — such as handling validation, computing a score, or managing events — rather than mixing multiple concerns in one place. This separation makes the system easier to understand, test, and maintain, and prevents changes in one area from unintentionally affecting others.

Each Rubric’s scoring logic is implemented and validated individually, then integrated into the Assessment Mechanism. Existing logic remains unchanged, while new Rubric logic can be added freely — illustrating the Open/Closed Principle (OCP) in action.

At the same time, each Rubric focuses on a single, well-defined scoring responsibility, ensuring clear separation of concerns — a direct application of the Single Responsibility Principle (SRP). Together, these principles make the assessment mechanism easy to maintain and extend over time.

## Event-driven Assessment Mechanism

Eric Evans introduced the concept of Domain Event when explaining Domain-Driven Design. We won’t go into details here, what we need to know is that the purpose of Domain Events is to explicitly express business facts, decouple system modules, support asynchronous operations and eventual consistency, while also improving the system’s testability, maintainability, and auditability.

The diagram below illustrates the event-driven Assessment Mechanism I designed. I will now explain how it fulfills the purposes mentioned earlier.


<div class="mermaid">
graph TD

    %% Events
    Event1[Event1<br/>IAssessEvent] -->|trigger| Dispatcher[AssessEventDispatcher]
    Event2[Event2<br/>IAssessEvent] -->|trigger| Dispatcher[AssessEventDispatcher]
    Event3[Event3<br/>IAssessEvent] -->|trigger| Dispatcher[AssessEventDispatcher]

    %% Handlers
    Handler1[Event1Handler<br/>BaseEventHandler&lt;Event1&gt;] -->|register| Dispatcher
    Handler2[Event2Handler<br/>BaseEventHandler&lt;Event2&gt;] -->|register| Dispatcher
    Handler3[Event3Handler<br/>BaseEventHandler&lt;Event3&gt;] -->|register| Dispatcher

    %% Dispatcher dispatches to handlers
    Dispatcher -->|dispatch Event1| Handler1
    Dispatcher -->|dispatch Event2| Handler2
    Dispatcher -->|dispatch Event3| Handler3


    %% Handlers call service
    Handler1 -->|Invoke Business Logic| Service[ComplianceService]
    Handler2 -->|Invoke Business Logic| Service
    Handler3 -->|Invoke Business Logic| Service

    classDef eventStyle fill:#e2e,stroke:#333,stroke-width:1px;
    classDef dispatcherStyle fill:#11d,stroke:#333,stroke-width:1px;
    classDef handlerStyle fill:#bfb,stroke:#333,stroke-width:1px;
    classDef serviceStyle fill:#ffb,stroke:#333,stroke-width:1px;

    class Event1,Event2,Event3 eventStyle
    class Dispatcher dispatcherStyle
    class Handler1,Handler2,Handler3 handlerStyle
    class Service serviceStyle

</div>

### IAssessEvent & IAssessEventHandler

Programming to interfaces serves as the fundamental basis for realizing the Open/Closed Principle (OCP). Within the Assessment Mechanism, two interfaces are defined to facilitate the dispatching of events in AssessEventDispatcher, decoupling the event processing logic from specific implementations.

<div class="mermaid">
classDiagram
    class IAssessEvent {
      ...
      +Points: int
      +IsValid: bool
      ...
    }

    %% Interface
    class IAssessEventHandler~T~ {
        +HandleAsync(T assessEvent) : Task
    }

    %% Abstract class
    class BaseAssessEventHandler~T~ {
        +HandleAsync(assessEvent: T) : Task
        #DoAssessment(assessEvent: T) : Task~int~
    }

    %% Relationships
    IAssessEventHandler~T~ <|.. BaseAssessEventHandler~T~
</div>

AssessEventDispatcher serves as the core component that realizes the Open/Closed Principle (OCP). It is responsible for registering the appropriate EventHandler for each event type and dispatching triggered events to their corresponding handlers for processing. This design allows new event types and handlers to be introduced without modifying the dispatcher’s internal logic, ensuring extensibility while preserving stability. When new events are defined and implemented, the existing code remains unchanged — it is closed for modification. New functionality is introduced by adding new event types and their corresponding EventHandler implementations — open for extension. 


```csharp
public class AssessEventDispatcher
{
  private readonly IDictionary<Type, object> _handlers = new Dictionary<Type, object>();

  public void RegisterHandler<T>(IAssessEventHandler<T> handler) where T : IAssessEvent
  {
    ...
    var eventType = typeof(T);
    ...
    _handlers[eventType] = handler;
  }

  public async Task DispatchAsync<T>(T assessEvent) where T : IAssessEvent
  {
    ...
    if (!assessEvent.IsValid)
    {
      return;
    }

    var eventType = assessEvent.GetType();
    if (_handlers.TryGetValue(eventType, out var handler))
    {
      await ((IAssessEventHandler<T>)handler).HandleAsync(assessEvent);
    }
    ...
  }
}
```

BaseAssessEventHandler implements the IAssessEventHandler interface and serves as an illustration of the Open/Closed Principle (OCP). The HandleAsync method encapsulates the stable, generic workflow for processing events, which is closed to modification. The abstract DoAssessment method, on the other hand, delegates the domain-specific scoring logic to concrete implementations, remaining open for extension and allowing new event types to be introduced without altering the existing workflow.

```csharp
public abstract class BaseAssessEventHandler<T> : IAssessEventHandler<T> where T : IAssessment
{
  protected abstract Task<int> DoAssessment(T assessEvent);

  public async Task HandleAsync(T assessEvent)
  {
    var score  = await DoAssessment(assessEvent);
    // Process Payee Compliance
    ...
    // Create Assessment log
    ...
  }
}
```


####  Interfaces implementations
All events will implement the IAssessEvent interface. Each type of event has a corresponding EventHandler responsible for encapsulating the logic for processing that event. BaseAssessEventHandler also implements the IAssessEventHandler interface. This is because all AssessEvent types in the project share a similar processing workflow: scoring → handling compliance → logging. Therefore, this process is extracted into the base class, allowing subclasses to focus solely on implementing their own scoring logic.

Each event class leverages Points and IsValid to encapsulate its domain-specific business logic: Points reflects the score computed according to the event’s specific rules, while IsValid determines whether the event is eligible for processing by the Dispatcher. Consequently, modifications to these classes are required only when the underlying business rules of their respective domains—such as scoring logic—change.
<div class="mermaid">
graph LR
    A[Scoring] --> B[Handling Compliance]
    B --> C[Logging]

    classDef scoringStyle fill:#111fff,stroke:#333,stroke-width:2px,corner-radius:10px,font-weight:bold;

    class A scoringStyle;
</div>

In BaseAssessEventHandler, the HandleAsync method implements the workflow described above, while exposing the abstract DoAssessment method for subclasses to implement their own scoring logic.




### OCP implementation



