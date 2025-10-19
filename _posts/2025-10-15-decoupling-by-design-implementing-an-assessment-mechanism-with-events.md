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

## OCP & S﻿RP

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



### SRP imlementation

All events will implement the IAssessEvent interface. The class diagram below shows two important properties.
<div class="mermaid">
classDiagram
    class IAssessEvent {
      ...
      +Points: int
      +IsValid: bool
      ...
    }
</div>

#### Points

* Points represents the score calculated according to business rules.

* Each event class encapsulates the business logic specific to its own domain independently. For example, the parameters used for calculations vary greatly between different events.

* Each event class has only one reason to change — a change in the business rules of its own domain — and does not affect other event classes.


#### IsValid

* IsValid encapsulates the business logic that determines whether an event is valid, preventing the Dispatcher from dispatching invalid events to the corresponding EventHandler.

* The criteria for validity may differ between events, reflecting the domain-specific rules of each event type.

* While technically validity could be inferred from Points (for example, events with a score of 0 may require no processing and can be considered invalid), relying solely on the score hides important domain knowledge embedded in the business rules.

* By defining IsValid as part of the IAssessEvent interface, each event class implements its own logic independently, so changes in the business rules of one event do not affect other events.

#### Sample

The following shows a partial implementation example of the ReportPageAssessEvent event.


```csharp
public class ReportPageAssessEvent : IAssessEvent
{
  ...
  private readonly Status _currentState;
  private readonly Status _newState;

  ...

  public bool IsValid => _currentState == Status.Support || _newState == Status.Support

  public int Points => (_currentState, _newState) switch
  {
    (_ Status.Support) => 1,
    (Status.Support, _) => -1,
    _ => 0
  }
  ...

}

```

* Points represents the score calculated according to business rules:

* Supporting a report increases the score by 1.

* If a report that was previously supported is later clarified, the score decreases by 1.

* In all other cases, the score is 0.

* IsValid encapsulates the criteria for event validity: an event is valid if either the current state or the new state is Support. Events that do not involve the Support status are considered invalid, since only Support contributes to the score.

* By encapsulating both the scoring logic and the validity logic within ReportPageAssessEvent, the class makes the business rules and domain knowledge explicit, clear, and easy to maintain.



### OCP implementation
