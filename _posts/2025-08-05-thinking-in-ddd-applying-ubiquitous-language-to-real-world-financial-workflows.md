---
title: "Thinking in DDD: Applying Ubiquitous Language to Real-World Financial
  Workflows"
date: 2025-08-09T12:52:54.217Z
toc: true
categories:
  - Architecture
tags:
  - System Design
---
Software engineers need domain knowledge to build business systems. I’ve found that domain experts often explain processes but rarely define key entities clearly and completely. At nearly every company I’ve joined, business and technical teams present views of the system from their own perspectives, often resulting in fragmented information. It typically takes months of development involvement to connect the dots and form a cohesive understanding. This process is often fraught with doubt, anxiety, and mistrust, affecting collaboration. A clear and structured approach to communication can foster shared understanding and make change easier to embrace.

Ubiquitous Language is the starting point of that path.

## Essentials﻿ in Ubiquitous Language

*Ubiquitous Language* is a familiar concept to many engineers. While I first encountered it in Eric Evans’ book, in practice, every team I’ve worked with has naturally used it to communicate. *Ubiquitous Language* can be seen as a **shared, precise vocabulary** developed and continuously refined by both domain experts and developers, **centered around the domain model**, and **consistently used in all team communication and code** to ensure clarity, alignment, and deep understanding of the business domain.

The problem is that we use it daily without being fully aware of it. Cross-team communication often conveys only context-specific fragments of domain knowledge, evolving with each exchange. As Ubiquitous Language comprises precise terms for conveying domain knowledge, domain experts(or anyone familiar with the business) can curate a glossary of key concepts. This should enable team members to align on terminology, facilitating clear and efficient communication quickly.

Earlier this year, I worked on a project in the finance domain and went through the typical challenges of learning a new domain. To consolidate my understanding and validate the concept of Ubiquitous Language, I’ll draft a domain-specific glossary. If readers can quickly understand the financial processes through it, that would demonstrate its effectiveness.

## Business Language-stated requirement

This requirement is straightforward: automate the creation of invoices for donation payments to reduce manual effort. To fully grasp the 'Invoice' process, I consulted colleagues familiar with the workflow and reviewed the code, ultimately clarifying all implementation details.
(Please note: F & D = Fundraise & Donate Platform)

<div class="mermaid">
flowchart TD
    A[Donor makes donation on F & D] --> B[Payment processed by Windcave DPS]
    B --> C[Funds settled into F & D Trust Account]
    C --> D[Reconciliation in F & D]
    D --> E[Monthly payout calculation]
    E --> F[Accounting & payout statement generated in Xero]
    F --> G[Bulk payment file prepared in Xero]
    G --> H[Funds transferred via bank to beneficiary account]
    F --> I[Payout statement sent to beneficiary]
</div>
The flowchart above concisely depicts the full process in which 'invoice generation' occurs. Once the new donations are created, the customer service team uploads the related Windcave DPS file to trigger the subsequent steps, completing the payout. This flowchart was developed through multiple discussions and repeated code reviews. I also referred to some related documents, though most were intended for those already familiar with the process and were not particularly beginner-friendly.

Therefore, for engineers new to the financial domain, understanding the development-related knowledge and logic in this process is not easy.

## Ubiquitous Language-stated requirement

Eric Evans introduced the explanatory model concept to succinctly represent domain knowledge. Below is the explanatory model for this requirement.

<div class="mermaid">
flowchart TD
A[Donation Creation] --> B[Payment Processing]
    B --> C[Reconciliation]
    C --> D[Accounting and Payout]

```
A_remark([Donation Record Created])
B_remark([DPS File Generated])
C_remark([Reconciliation Report])
D_remark([Invoices Created])

A_sys((F & D))
B_sys((Windcave))
C_sys((F & D))
D_sys((Xero))

A -.-> A_remark
B -.-> B_remark
C -.-> C_remark
D -.-> D_remark

A_remark -.-> A_sys
B_remark -.-> B_sys
C_remark -.-> C_sys
D_remark -.-> D_sys

classDef remarkNode fill:#f9f,stroke:#333,stroke-dasharray: 4 2,color:#333,font-style:italic;
classDef systemNode fill:#bbf,stroke:#33f,color:#004,font-weight:bold;
classDef docButton fill:#4CAF50,stroke:#2E7D32,color:#fff,font-weight:bold,stroke-width:2,rx:8,ry:8,cursor:pointer;

class A_remark,C_remark remarkNode;
class B_remark,D_remark docButton;
class A_sys,B_sys,C_sys,D_sys systemNode;
```

</div>

This explanatory model, derived from the flowchart, is more practical for engineers. It simplifies the process by mapping key steps to business systems and the data protocols they exchange.

Both the flowchart and explanatory model aim to help engineers overcome domain knowledge gaps and grasp business requirements accurately. Hence, detailed aspects like payment types, transfers, and fee calculations are omitted.

### Glossory

* ***Donation***: A financial contribution initiated by a donor, recorded in the F & D system.

* ***Payment***: The payment action related to a Donation, processed by Windcave (which generates the DPS File) and also recorded in F & D.

* ***DPS File***: A Daily Payment Summary file generated by Windcave containing payment details, used as input for Reconciliation. 

* ***Reconciliation***:	The process in GAL that matches Donation and Payment data to validate fund flow and trigger Payout.

* ***Payout***: The disbursement of funds to beneficiaries, accompanied by Invoice creation in Xero.

* ***Windcave***: A payment service that securely processes donations across multiple channels and creates payment summary files (DPS) used for tracking and reconciliation.

* ***Xero***: A cloud-based accounting system that manages financial operations such as invoice creation and payout tracking. In this flow, Xero generates invoices related to donation payouts and triggers the bank system to transfer funds from F & D to the beneficiaries, ensuring accurate financial records.

* ***Invoice***: A financial document created in Xero to record payment requests for donation payouts. Invoices correspond to the verified payment data from the Reconciliation process in GAL and serve as proof for triggering payouts to beneficiaries.

## Personal Reflections

The definitions provided here are practical within the context of the current requirement but may represent only parts of their complete meanings. In other scenarios, some key information might be missing, making these definitions less precise. Therefore, they require continuous refinement. Modeling and documenting domain knowledge is challenging and often reflects individual preferences rather than a fixed task.

Ubiquitous Language has always been used implicitly within team collaboration—for example, in the terminology used during requirement discussions and the naming of objects in code. It is not necessary to create explanatory models or glossaries for every domain concept, but having such a reference undoubtedly helps all participants quickly align and collaborate smoothly and efficiently.

Another challenge I face is that domain knowledge is easily forgotten. This means when picking up tasks in the same domain after some time, I often feel less confident and have to familiarize myself with the details repeatedly. Excessive repeated discussions can indeed dampen enthusiasm. As an engineer, this is one approach I’ve considered to address the issue—I hope it can be helpful to you as well.