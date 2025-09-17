---
title: "Thinking in DDD: Understanding Entities, Value Objects, and Aggregates
  through a Crowdfunding Page"
date: 2025-09-16T20:42:10.152Z
toc: true
categories:
  - Architecture
tags:
  - System Design
  - C#
  - Code Refactoring
---
Domain-Driven Design introduces several important modeling objects in the domain model, as follows:

* ***Entity*** – An object defined by its identity rather than its attributes.
* ***Value Object*** – An immutable object defined only by its values, with no unique identity.
* ***Aggregate*** – A cluster of associated objects treated as a unit, with a single Aggregate Root ensuring consistency.
* ***Factory*** – A construct that encapsulates complex creation logic for objects or aggregates.
* ***Repository*** – An abstraction that provides access to aggregates, simulating a collection in memory while hiding persistence details.
* ***Service*** – A stateless operation or functionality that does not naturally belong to an Entity or Value Object.

Proper use of these modeling objects is crucial for simplifying the expression of a domain model. Below, I will illustrate how to use these objects by constructing a simple domain model centered around an important concept in the crowdfunding domain — Page. Of course, the business logic contained in a Page in a real crowdfunding system is much more complex.

## The Page in a Crowdfunding System

In a crowdfunding platform, a Page is the heart of fundraising. It represents a campaign with key details — title, description, target amount, and timeline.

Pages are dynamic: donors contribute, supporters comment, owners post updates, and progress is tracked. They enforce rules like donation limits, deadlines, and visibility.

In the domain model, a Page is an aggregate root, linking Donations, Comments, and the PageOwner while preserving campaign integrity. This shows how a central concept can structure a domain and guide Domain-Driven Design.

<div class="mermaid">
classDiagram
    %% Page Core class
    class Page {
        +string Title
        +string Description
        +decimal TargetAmount
        +decimal RaisedAmount
        +PageStatus Status
        +Date StartDate
        +Date EndDate
    }

    %% Relevant objects
    class Donation {
        +decimal Amount
        +Date DonateAt
        +string Message
    }

    class Comment {
        +string Content
        +Date CreatedAt
    }

    class Profile {
        +string Name
        +string Email
    }


    class Beneficiary {
        +string Name
        +string ContactInfo
    }


    %% Relationships
    Page "1" --> "0..*" Donation : receives
    Donation "0..*" --> "1" Profile : donor

    Page "1" --> "0..*" Comment : receives
    Comment "0..*" --> "1" Profile : author

    Page "0..*" --> "1" Profile : Owned by

    Page "1" --> "1..*" Beneficiary : benefits
   
   
</div>

