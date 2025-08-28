---
title: Page Splits or Hotspots? Choosing the Right Primary Key in SQL Server
date: 2025-08-27T10:01:28.566Z
toc: true
categories:
  - Backend
tags:
  - SQL Server
  - System Design
---
All data tables in the project use Guid as the primary key. Most of them are randomly generated Guids, but quite a few tables use Sequential Guid. For example, the primary key can be specified as a Sequential Guid in the following two ways."

T-SQL

```sql
...
Id UNIQUEIDENTIFIER NOT NULL 
  CONSTRAINT DF_MyTable_Id DEFAULT NEWSEQUENTIALID() PRIMARY KEY,
...
```

EntityFramework

```csharp
...
entity.Property(e => e.Id).HasDefaultValueSql("(newsequentialid())");
...
```
I’m a bit puzzled—what is the rationale behind this difference? The following research should help clarify this question.

## Page split problem of random primary keys
In a database, data is managed and stored through pages. The diagram below illustrates the structure of a clustered index page. The page size is fixed, and page splits are used to expand storage for additional data.

![Clustered Index Page]({{ "uploads/clustered-index-page.png" | relative_url }})

Frequent page splits can hurt database performance because:

* ***Extra I/O and CPU:*** Splitting a page means copying rows to a new page and updating pointers, which is far more work than a normal insert.

* ***Fragmentation:*** Pages end up only half full and out of order, wasting space and slowing down scans.

* ***Locking and Blocking:*** Splits require page locks, which can block other queries under high concurrency.

* ***Reduced Cache Efficiency:*** Half-empty pages mean fewer rows fit in memory, leading to more disk reads.

Random primary keys, like GUIDs created with NEWID, can lead to frequent page splits. This happens because new data rows must be inserted randomly into existing data pages instead of being appended in an orderly fashion. When a page is full, the database must perform an expensive page split to make room, which severely impacts performance.

## Hot page contention with sequential primary keys

## Strategies for choosing primary keys