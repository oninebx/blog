---
title: "Thinking in DDD: Applying Ubiquitous Language to Real-World Financial
  Workflows"
date: 2025-08-05T22:44:23.007Z
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

## Business-stated requirement

This requirement is straightforward: automate the creation of invoices for donation payments to reduce manual effort. However, without financial knowledge, understanding and assimilating this requirement is not straightforward. After multiple discussions with colleagues familiar with the process, I have gained a general understanding of the necessary domain knowledge, which is crucial for working with the existing code and conducting local testing during development.

Eric Evans introduced the explanatory model concept to succinctly represent domain knowledge. Below is the explanatory model for this requirement.

<div class="mermaid">
A[Donation Creation] --> B[Payment Processing]
    B --> C[Reconciliation]
    C --> D[Payouts and Accounting]

    A_remark([Donation Record Created])
    B_remark([DPS File Generated])
    C_remark([Reconciliation Report])
    D_remark([Invoices Created])

    A_sys((GAL))
    B_sys((Windcave))
    C_sys((GAL))
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
</div>