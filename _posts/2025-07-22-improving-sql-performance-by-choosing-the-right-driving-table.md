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
Recently, I solved several slow query issues at work, all of which were related to choosing the correct driving table for the query. The following example is much simpler than the real business scenarios, but it is sufficient to illustrate the problem. 

## Business scenario and data description

We want to list the Profiles of unverified Payees and their total donation amount. The test data comprises approximately 100,000 Payee records and 300,000 Donation records. While ensuring correct query results, the query performance differs significantly depending on which of these two tables is chosen as the driving table. Although there is only one Payee in the test data that meets the criteria, comparing the query execution times is enough to demonstrate the issue. The necessary relationships and fields of the tables are shown below. 

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
    uniqueidentifier Id PK
    uniqueidentifier PayeeId FK
    nvarchar FullName
    datetime CreatedAt
}

CausePage {
    uniqueidentifier Id PK
    nvarchar Title
    nvarchar Description
    decimal TargetAmount
    uniqueidentifier ProfileId FK
    datetime CreatedAt
}

Donation {
    uniqueidentifier Id PK
    uniqueidentifier CausePageId FK
    decimal Amount
    nvarchar Currency
    datetime DonatedAt
    bit IsProcessed
}

</div>

## Slow Query (Payee as the Driving Table)

Starting from Payee, SQL Server will **scan all Payees**, join with Profiles, then CausePages, and finally Donations. In reality, although there are many Payees, only a few have donations. Most rows will be filtered out late, resulting in a slow query.

```sql
SELECT 
    pa.Id AS PayeeId,
    pa.Name,
    SUM(d.Amount) AS TotalProcessedAmount
FROM Payee pa
JOIN Profile pr ON pa.Id = pr.PayeeId
JOIN CausePage cp ON cp.ProfileId = pr.Id
JOIN Donation d ON d.CausePageId = cp.Id
WHERE pa.Verified = 0
  AND d.IsProcessed = 1
GROUP BY pa.Id, pa.Name
HAVING SUM(d.Amount) > 0;
```

I ran this query locally, and it took ***2,677*** milliseconds.

## Fast Query (Donation as the Driving Table)

Starting from `Donation` filters **only relevant data first**, because it goes directly to where the majority of filtering occurs (e.g., processed donations). This query avoids scanning irrelevant Payee records by starting from Donation (already filtered by IsProcessed = 1), so only Payees with donations are visited.

```sql
SELECT 
    pa.Id AS PayeeId,
    pa.Name,
    SUM(d.Amount) AS TotalProcessedAmount
FROM Payee pa
JOIN Profile pr ON pa.Id = pr.PayeeId
JOIN CausePage cp ON cp.ProfileId = pr.Id
JOIN Donation d ON d.CausePageId = cp.Id
WHERE pa.Verified = 0
  AND d.IsProcessed = 1
GROUP BY pa.Id, pa.Name
HAVING SUM(d.Amount) > 0;
```

I ran this query locally, and it took ***179*** milliseconds.

## Key takeaways

The real business scenarios are much more complex than this example, with more returned fields and data, more aggregation queries, and more tables. Although query execution time is not simply a linear accumulation, choosing the wrong driving table can make queries extremely slow or even cause timeouts, severely affecting user experience and consuming unnecessary computing resources. In real cases, we dealt with more complex business scenarios and resolved query timeout issues by selecting the correct driving table, initially reducing the query time to a user-acceptable level of over ten seconds. Then, by analyzing the execution plan and creating a key index, we ultimately optimized the query time to around one second. 

Thanks to AI for helping me generate the scripts for the examples in this article, which saved me a lot of time.

[Download the T-SQL Sample]({{ "uploads/DrivingTable.sql" | relative_url }})