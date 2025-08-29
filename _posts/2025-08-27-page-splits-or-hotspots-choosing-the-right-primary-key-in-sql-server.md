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

Random primary keys, like GUIDs created with NEWID in T-SQL, can lead to frequent page splits. This happens because new data rows must be inserted randomly into existing data pages instead of being appended in an orderly fashion. When a page is full, the database must perform an expensive page split to make room, which severely impacts performance.

The split process is illustrated in the diagram below.

<div class="mermaid">
flowchart LR
    subgraph Initial["Before Insert"]

      P1["Page 1<br/>a8...<br/>b5..."]
      P2["Page 2<br/>a9...<br/>b6...<br/>b7..."]
      P3["Page 3<br/>e9...<br/>f0...<br/>f1..."]
    end

    New["Insert new GUID d4..."] --> Initial

    subgraph Split["After Page Split"]
      P1a["Page 1<br/>a8...<br/>b5..."]
      P2a["Page 2<br/>a9...<br/>b6...<br/>b7..."]
      P3a["Page 3<br/>d4...<br/>e9..."]
      P4["Page 4<br/>f0...<br/>f1..."]
    end

    Initial -->|Split occurs| Split

    classDef page fill:#e6f7ff,stroke:#1f77b4,stroke-width:1px;
    class P1,P2,P3,P1a,P2a,P3a,P4 page;


</div>

## Hot page contention with sequential primary keys
One way to avoid frequent page splits is to use sequential primary keys, such as incremental integer keys or Sequential GUIDs. Sequential primary keys avoid frequent page splits because new rows are always inserted at the end of the index, reducing random mid-page inserts and keeping data pages in order. The incremental integer primary key strictly adheres to this strategy, whereas the Sequential GUID, due to the nature of its generation algorithm, does not fully comply and therefore incurs more page splits than the integer key.

Sequential keys reduce page splits, meaning the same amount of data can be stored in fewer pages. This looks beneficial, but unfortunately, under high-concurrency writes, it leads to a more severe performance issue—hot page contention. When a table uses a sequential primary key, all new rows are inserted into the last page of the clustered index, which minimizes page splits and fragmentation. However, under high-concurrency workloads, this “concentrated insert” pattern causes many transactions to compete for latches or locks on the same page, resulting in hot page contention. The performance bottlenecks manifest as limited throughput that does not scale with concurrency, increased wait times (such as PAGELATCH_EX in SQL Server), low CPU utilization despite heavy workloads, and significantly higher response times, ultimately constraining overall write performance.

<div class="mermaid">
graph LR
    P1[Page 1] --> P2[Page 2] --> P3[Page 3]
    P3 --> P4[Page 4 Last Page]

    subgraph Inserts
        I1[Insert 1] --> L
        I2[Insert 2] --> L
        I3[Insert 3] --> L
        I4[Insert 4] --> L
        subgraph HPC[Hot Page Contention⚠️]
          L[Latch 🔒] ---> P4
        end
    end

    style L fill:#5566cc,stroke:#d90,stroke-width:2px,color:yellow
    style HPC fill:#667788,stroke:#f00,stroke-width:2px,color:red

</div>


## Strategies for choosing primary keys

When selecting primary keys, it is important to balance the trade-off between page splits and hot page contention:

* ***Random Keys*** (e.g., GUIDs) distribute inserts across multiple pages, which reduces contention but increases the frequency of page splits and fragmentation.

* ***Sequential Keys*** (e.g., identity or sequential GUIDs) minimize page splits by appending new rows to the end of the index, but concentrate all writes on the same page, leading to hot page contention under high concurrency.

### Primary Key Strategies by Workload

* ***For Read-Heavy or Distributed Systems:*** For workloads dominated by reads, random keys (like GUIDs) may be a good choice. Their unpredictable nature helps distribute data writes across multiple pages, which can reduce hot page contention and be beneficial in distributed environments. However, this comes at the cost of increased fragmentation.

* ***For Moderate Write Workloads and Efficient Queries:*** If your system has moderate write activity and frequently performs range queries, sequential keys (such as identity columns or sequential GUIDs) are generally the best option. They minimize page splits and keep data physically ordered, which dramatically improves the performance of SELECT queries with WHERE clauses on the primary key.

* ***For High-Concurrency, Write-Heavy Systems:*** For systems that require both high scalability and fast writes, you should consider hybrid strategies. Techniques like key sharding, partitioning, or using a non-clustered unique identifier alongside a sequential surrogate clustering key can balance the needs for both efficient writes and reads, mitigating both hot page contention and fragmentation.

## Key takeaways

Here's an [experimental script]({{ "uploads/PageTestExperiment.sql" | relative_url }}) to demonstrate the page splitting caused by random primary keys and the hot page contention problem with sequential primary keys. Please use [SQLQueryStress](https://github.com/ErikEJ/SqlQueryStress) to execute the script concurrently.

### Sequential Primary Key test results

Hot page contention slows down data insertion.

![page-test-sequential-int]({{ "uploads/page-test-sequential-int.png" | relative_url }})

![hotspot-page-contention-sequential-int-latch]({{ "uploads/hotspot-page-contention-sequential-int-latch.png" | relative_url }})

### Random Primary Key test results

Random Primary Key alleviates hot page contention.

![page-test-random-guid]({{ "uploads/page-test-random-guid.png" | relative_url }})

![hotspot-page-contention-random-guid-latch]({{ "uploads/hotspot-page-contention-random-guid-latch.png" | relative_url }})

### Page Splits Comprison

While sequential primary keys are designed to reduce page splits, the high level of write concurrency still led to significant splitting. Nevertheless, the total number of page split events was notably lower than those caused by random primary keys.

![hcompare-page-splits]({{ "uploads/compare-page-splits.png" | relative_url }})