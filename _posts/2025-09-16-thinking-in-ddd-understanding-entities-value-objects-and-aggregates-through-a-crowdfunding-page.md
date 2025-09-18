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

The diagram above illustrates the structure of Page, which can be used directly as the classes in the project, though it does not fully reflect the domain knowledge.

## The Domain Objects in Page Context

Here, ‘Context’ refers to a Bounded Context—a way to simplify modeling in complex systems. We’ll temporarily call it ‘Page’. The name may not capture the core business, but it shows that this part is related to ‘Page’.

### Entities

An **Entity** is a domain object defined by its unique identity rather than its attributes. It can have mutable state and encapsulate business rules that govern its lifecycle and interactions with related objects. Entities often aggregate or reference other entities and value objects, ensuring consistency within their boundaries.

* **Page**: Page is an Entity because it has a persistent identity and mutable state, and it is the **aggregate root** because it encapsulates the campaign’s lifecycle, enforces business rules, and anchors all related entities and value objects, providing a clear and consistent transactional boundary for the crowdfunding campaign.
* **Donation**: Donation is an Entity because each contribution has a unique identity, a lifecycle like created, processed, and potentially refunded or canceled, and enforces business rules like valid donor and positive amounts. It maintains relationships with its Page and Donor, allowing the system to track and manage each donation consistently.
* **Comment**: Comment is an Entity because each comment has a unique identity that distinguishes it from all other comments, even if multiple comments have the same content, author, or timestamp. Its identity ensures that the system can track, reference, or manage each comment individually.
* **Beneficiary**: Beneficiary is an Entity because it has a persistent identity, a mutable lifecycle, and relationships with Pages and Donations. Its identity ensures that funds are accurately tracked, business rules are enforced, and accountability is maintained, even when multiple beneficiaries have similar attributes.

### V﻿alue Objects

Value Objects (VOs) are immutable and defined by their values. They capture domain concepts precisely, enforce rules at creation, and make the system safer and easier to understand. By handling details, they let Entities focus on behavior while improving clarity and reliability in the domain model.

* **C﻿ampaignStory**: Encapsulate a campaign’s narrative - its purpose, goals, and presentation. It includes Title, Content, Summary, and ImageUrl, each with validation rules (e.g., `Title` is required and limited to 50 characters).
* **Timeline**: Represent the start and end dates of a fundraising campaign. It encapsulates the campaign’s duration and enforces business rules, such as the start date must precede the end date, and the campaign cannot end in the past. 
* **DonationAmount**: Represents the value of a donation and encapsulates the logic to compute its total amount. It combines the supporter’s base donation, platform fees, and payment method fees (e.g., credit card), with the sum representing the total amount the supporter actually pays.

The identification and extraction of Value Objects (VOs) is an ongoing, iterative process, and the results may vary between individuals and over time. Regardless, we should keep in mind that the purpose of defining VOs is to express rich business rules in the domain model in a clear and understandable way. A VO does not necessarily need multiple attributes - it can consist of just one - as long as the business rules it encapsulates are significant enough to warrant extraction and encapsulation.

### A﻿ggregate & Aggregate Root

An **Aggregate** is a cluster of related entities and value objects that are treated as a single unit to enforce business rules and maintain consistency. The **Aggregate Root** is the primary entity within the aggregate that controls access to its internal objects, ensuring all invariants are preserved. External objects interact only with the aggregate root, which acts as a gatekeeper, coordinating changes and protecting the integrity of the aggregate’s state.

In the Page aggregate of a crowdfunding platform, **only the Page itself serves as the Aggregate Root**. Other entities, such as **Donation**, **Comment**, or **Beneficiary**, cannot act as aggregate roots because they do not have the full knowledge or authority to enforce the aggregate’s business rules on their own. For example, a Donation cannot independently ensure that the total raised amount does not exceed the campaign’s target, and a Comment cannot verify the Page’s status before being added. Only the Page has visibility and control over all related entities and value objects, allowing it to enforce invariants, coordinate changes, and maintain the integrity of the entire campaign. This ensures that all operations pass through a single gatekeeper, preventing inconsistencies and preserving the aggregate’s transactional boundaries.

### F﻿actories

**Factory** is a pattern used to encapsulate the complex creation logic of domain objects, particularly entities and aggregates. Instead of exposing constructors directly, a factory handles the assembly of an object’s required components, ensures that all business rules and invariants are satisfied at creation, and can coordinate the creation of related entities or value objects. Factories are especially useful when creating aggregates like a Page, where multiple entities (Donations, Comments, Beneficiary) and value objects (CampaignStory, Timeline) must be initialized consistently and correctly from the start.

#### PageFactory

A **PageFactory** is essential because Pages of different types— like **Cause**, **Project**, and **Fundraiser**—have distinct business rules and initialization requirements. For example, a Cause page allows an arbitrary `TargetAmount`, whereas a Project page requires a fixed `TargetAmount`. A Fundraiser page, on the other hand, coordinates multiple Cause pages, establishing relationships between them and managing the aggregated fundraising logic. By centralizing all type-specific creation logic and associated business rules within the factory, the system ensures that each Page is initialized correctly, all invariants are satisfied, and related entities or value objects are properly set up. This consolidation of creation logic not only guarantees consistency but also improves code readability and maintainability, as developers can understand the rules for creating any Page in one place.

#### DonationFactory

A **DonationFactory** is also essential in a robust crowdfunding ecosystem because creating a Donation involves multiple sources and complex business rules. Donations may come from one-time contributions, **Regular Giving**, or **Payroll Giving**, and each source may have distinct processing requirements. Additionally, different **payment methods** apply varying fee rates, and each Page can enforce specific minimum and maximum donation amounts. By encapsulating all these rules within a factory, the system ensures that every Donation is created consistently, respects limits, calculates fees accurately, and maintains the integrity of the Page aggregate. In a real system, the rules around creating a Donation are more complex, so it is fully justified to introduce a factory for Donation.

### Repositories

**Repository** abstracts persistence and provides access to aggregates as if they were in-memory collections. They operate only at the **aggregate root level**, ensuring boundaries and business rules are preserved. While **Factories** handle the creation of complex aggregates, **Repositories** take responsibility for retrieving and storing them. Together, they keep the domain model clean and focused on business logic, free from infrastructure concerns.

**Page** is the only aggregate root, so the **PageRepository** is the single gateway for persistence. It provides simple access to Page aggregates—retrieving, saving, or removing them—while hiding database details. A Page is always handled as a whole, including its Donations, Comments, and Beneficiary, ensuring business rules are enforced through the aggregate root.

When implementing repositories, it is a common practice to define a generic base class that encapsulates common query operations. This approach reduces boilerplate code, promotes consistency across repositories, and allows developers to focus on aggregate-specific logic rather than repeating infrastructure concerns.

### Domain Services

**Domain Service** encapsulates business logic that doesn’t naturally belong to a single Entity or Value Object. It is stateless, operates on the domain model, and handles behavior that may span multiple aggregates, keeping complex rules within the domain layer.

In this aggregate, Page and Donation serve as core entities. Given the complexity of the business rules governing their interactions, it is appropriate to introduce a Domain Service to encapsulate and manage this logic. 

Below, we outline several business rules concerning the two entities; however, in practice, the rules and interactions are significantly more complex.

* **Donation Validation**:The donation amount must respect the associated Page’s `DonationLimit`, like Page's minimum and maximum constraints, remain positive, and so on.
* **Fee Calculation**: Fees are applied according to the chosen payment method.
* **Aggregate Updates**: The `Donation` entity must be recorded. The Page’s `RaisedAmount` must be updated to reflect the new donation.

This class is named `DonationProcessingService`. The diagram below illustrates one possible structure, in which `ProcessDonation` serves as the sole public method exposed externally.

<div class="mermaid">

classDiagram
    class DonationProcessingService {
        +ProcessDonation(Page page, Donation donation) 
        -ValidateDonationAmount(Donation donation, DonationLimit limit)
        -CalculateFee(Donation donation)
        -UpdateRaisedAmount(Page page, Donation donation) 
        -RecordDonation(Page page, Donation donation)
    }

</div>

## Conclusion

Effectively modeling a domain around its business rules is at the heart of Domain-Driven Design. Before learning DDD, I used the six common modeling constructs in projects but rarely defined them properly:

* Services were created arbitrarily

* Entities were treated merely as data holders

* Value objects were barely used

* Aggregates were not designed

* Repositories did not align with aggregates

As a result, the models grew bloated, lost their boundaries, and the code no longer reflected the domain, making it difficult for the team to grasp the domain knowledge and business logic efficiently.

By analyzing the Page concept in the crowdfunding domain and identifying the essential modeling objects, I gained deeper insights into domain modeling. This article draws on Chapters 5–7 of Domain-Driven Design: Tackling Complexity in the Heart of Software, and I hope this case study proves useful if you are exploring the book as well.

