---
title: Improving SQL Performance by Choosing the Right Driving Table
date: 2025-07-22T22:44:10.602Z
toc: true
categories:
  - Project Notes
tags:
  - T-SQL
  - Query Optimization
---
Recently, I optimized a timeout-prone query in our project to run within seconds. The technical team highly appreciated the improvement. There are some valuable lessons worth summarizing, and the most important one is identifying the correct driving table for the query.
For clarity, I’ll introduce the tables involved in the query optimization as examples. To avoid any risk of information leakage, only the necessary relationships and fields are included. As shown in the diagram below.

<div class="mermaid">
erDiagram
    Payee ||--o{ Profile : "is assigned to"
    Profile ||--o{ CausePage : "owns"
    CausePage ||--o{ Donation : "receives"
    
Payee {
    uniqueidentifier Id PK
    nvarchar Name
    bit Verified
    datetime CreatedAt
}

Profile {
    int Id PK
    int MemberId FK
    int PayeeId FK
    nvarchar FullName
    datetime CreatedAt
}

CausePage {
    int Id PK
    nvarchar Title
    nvarchar Description
    decimal TargetAmount
    int ProfileId FK
    datetime CreatedAt
}

Donation {
    int Id PK
    int CausePageId FK
    decimal Amount
    nvarchar Currency
    datetime DonatedAt
    bit IsProcessed
}

</div>

[Download the T-SQL Sample]({{ "uploads/DrivingTable.sql" | relative_url }})
