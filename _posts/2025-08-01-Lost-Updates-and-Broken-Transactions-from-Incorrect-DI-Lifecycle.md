---
title: "Lost Updates and Broken Transactions from Incorrect DI Lifecycle"
date: 2025-08-01T10:12:00.595Z
toc: true
categories:
  - Project Notes
tags:
  - Entity Framework
  - ASP.NET
  - C#
---
I resolved a subtle issue months ago in a long-running company project that caused business data inconsistency due to confusing code changes. The project used an old .NET version where this issue could still occur — something newer versions have since addressed.

Understanding the root cause remains valuable, as it deepens our grasp of dependency injection lifecycles and helps prevent similar misuse in real-world scenarios.

## Confusing Code

```csharp
// Interface
public interface IAuditService
{
  ...
  void RecordChange(CoreDbContext context, int entityType, Guid entityId);
  ...
}

// Implementation
public class AuditService
{
  private readonly CoreDbContext _context;
  public AutitService(CoreDbContext context)
  {
    _context = context;
  }
  ...
  public RecordChanges(CoreDbContext context, int entityType, Guid entityId)
  {
    ...
    context.ChangeLogs.Add(new ChangeLog {
      ...
    });
    ...
  }
  ...
}

```
IAuditService records changes to entity properties. For example, when a Member's Name or Email changes, RecordChange saves all audit-relevant Member properties as a JSON string.

The inconsistency is that, despite injecting CoreDbContext via the constructor, the Record method uses a CoreDbContext instance passed as a parameter instead. This old and seemingly odd code worked perfectly—until I refactored it into the following form.

```csharp
...
  public RecordChanges(int entityType, Guid entityId)
  {
    ...
    _context.ChangeLogs.Add(new ChangeLog {
      ...
    });
    ...
  }
  ...

```
Obviously, the simplified code is easier to understand, but it throws an exception at runtime.

![exception]({{ "uploads/broken-transaction-exception.png" | relative_url }})

The project is structured using a layered architecture based on the Controller-Service-Repository pattern. There is a Member table and a ChangeLog table. When certain properties of a Member are updated, the relevant fields are serialized and stored as a record in the ChangeLog table. Since ChangeLog is designed to track changes for multiple types of entities, it includes EntityId and EntityType fields to distinguish the source of each change. To simplify the explanation, the service interfaces are omitted here. Although the dependency injection code may differ, it would lead to the same issue.

<div class="mermaid">
classDiagram
    class MemberController {
        +Update(MemberDto dto)
        -_memberService : MemberService
        -_changeLogService : ChangeLogService
    }

    class MemberService {
        +UpdateMember(MemberDto dto)
        -_dbContext : LifeTimeDbContext
    }

    class ChangeLogService {
        +LogChange(MemberDto dto)
        -_dbContext : LifeTimeDbContext
    }

    class MemberDto {
        +Id : int
        +Name : string
        +Email : string
    }

    class LifeTimeDbContext {
        +Members : DbSet<Member>
        +ChangeLogs : DbSet<ChangeLog>
    }

    class Member {
        +Id : int
        +Name : string
        +Email : string
    }

    class ChangeLog {
        +Id : int
        +EntityId : int
        +EntityType : string
        +ChangedData : string
        +ChangedAt : DateTime
    }

    MemberController --> MemberService : uses
    MemberController --> ChangeLogService : uses
    MemberController --> MemberDto : accepts
    MemberService --> MemberDto : uses
    ChangeLogService --> MemberDto : uses
    MemberService --> LifeTimeDbContext : injects
    ChangeLogService --> LifeTimeDbContext : injects
    LifeTimeDbContext --> Member : manages
    LifeTimeDbContext --> ChangeLog : manages

</div>


<div class="mermaid">
erDiagram
    MEMBER {
        int Id PK
        string Name
        string Email
        datetime UpdatedAt
    }

    CHANGELOG {
        int Id PK
        int EntityId
        string EntityType
        string ChangedData
        datetime ChangedAt
    }

    MEMBER ||--o{ CHANGELOG : logs

</div>
