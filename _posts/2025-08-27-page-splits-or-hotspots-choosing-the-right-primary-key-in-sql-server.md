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
![Clustered Index Page]({{ "uploads/clustered-index-page.png" | relative_url }})

## Hot page contention with sequential primary keys

## Strategies for choosing primary keys