---
title: "Rethinking SaveChanges: Transactional Boundaries and Best Practices in
  Entity Framework"
date: 2025-08-16T00:44:05.487Z
toc: true
categories:
  - Backend
tags:
  - Entity Framework
  - .NET
  - C#
  - SQL Server
---
In Entity Framework, SaveChanges and SaveChangesAsync are methods provided by DbContext to persist data. They are so commonly used that we rarely question their placement in code reviews. However, while refactoring a complex workflow recently, I noticed multiple calls to SaveChanges across different objects. This was due to insert and update operations spanning multiple tables and even multiple databases. 

Developers often tend to save data right after completing a key step. For example, when dealing with related data, a foreign key is expected to exist beforehand. However, as the following analysis shows, this approach is not always a best practice and can sometimes lead to issues with transaction consistency and performance.

To make this clearer, we’ll look at an example and then explore the best practice to resolve it. The sample code demonstrates the business scenario of:

* Any visitor can create a Cause Page.

* If they’re not already a registered member, the system creates a Member and their Profile first.

* Then, the Cause Page is created under that Profile.

* Finally, an AuditLog entry is written (in a different AuditDbContext).

* Each service calls SaveChangesAsync → multiple dispersed commits per request.


##  Bad Solution: Multiple SaveChangesAsync across services

### Sample Code

```csharp
// In CauseController

[HttpPost("create")]
public async Task<IActionResult> CreateCause([FromBody] CreateCauseDto dto)
{
  ...
  // If not registered, create member
  var member = await _memberService.GetOrCreateMemberAsync(dto.UserEmail);

  // Create profile for the member
  var profile = await _profileService.GetOrCreateProfileAsync(member.Id);

  // Create cause page under the profile
  var cause = await _causeService.CreateCauseAsync(profile.Id, dto.CauseTitle, dto.Description);

  // Log audit entry (separate AuditDbContext)
  await _auditService.LogAsync(member.Id, "Cause Page Created");
  ...
}

// In MemberService
public async Task<Member> GetOrCreateMemberAsync(string email)
{
  ...
  await _appDbContext.Members.AddAsync(newMember);
  await _appDbContext.SaveChangesAsync();
  ...
}

// In ProfileService
public async Task<Profile> GetOrCreateProfileAsync(int memberId)
{
  ...
  await _appDbContext.Profiles.AddAsync(newProfile);
  await _appDbContext.SaveChangesAsync();
  ...
}

// In CauseService
public async Task<Cause> CreateCauseAsync(int profileId, string title, string description)
{
  ...
  await _appDbContext.Causes.AddAsync(newCause);
  await _appDbContext.SaveChangesAsync();
  ...
}

// In AuditService
public async Task LogAsync(int memberId, string action)
{
  ...
  await _auditDbContext.AuditLogs.AddAsync(auditLog);
  await _auditDbContext.SaveChangesAsync();
  ...
}
```

### Problem Analysis

* ***Two DbContexts = Two Separate Transactions***

AppDbContext.SaveChangesAsync() commits Member, Profile, Cause. AuditDbContext.SaveChangesAsync() commits the audit trail. These two DbContexts do not share the same transaction. EF Core does not automatically coordinate them.

* ***Consistency Risk***

If saving business data succeeds but writing the audit log fails, you lose the log. If the audit is written first and the business save fails, you get a phantom log. Audit logs should always reflect real operations.

* ***Performance Issue***

If each service calls SaveChangesAsync separately, multiple transactions are opened and committed within the same request. This increases round-trips and adds latency.

* ***Atomicity Violation***

Business-wise, creating a Member, Profile, and Cause is one unit of work. Either all three succeed, or none should persist. By splitting the persistence into multiple commits, it breaks the atomicity guarantee that transactions are designed to provide.

## Good Solution: Unit of Work & BackgroundService pattern

Using a Unit of Work (UoW) pattern allows you to keep service methods focused on business logic (no SaveChangesAsync inside them) and persist all changes once at the controller (or orchestration) level. This is often considered best practice in enterprise applications. Here are the key code snippets of this solution.

```csharp
// In UnitOfWork

public class UnitOfWork : IUnitOfWork
{
    public AppDbContext DbContext { get; }

    public UnitOfWork(AppDbContext dbContext)
    {
        DbContext = dbContext;
    }

    public async Task<int> CommitAsync()
    {
        return await DbContext.SaveChangesAsync();
    }
}

// In OutboxService
public async Task QueueAuditAsync(string msg, Guid entityId)
{
    var outboxMessage = new OutboxMessage
    {
        Message = msg,
        EntityId = entityId,
        ...
        CreatedAt = DateTime.UtcNow,
        Processed = false
    };

    // Add to Outbox table; this is in the same DbContext transaction
    _appDbContext.OutboxEntries.Add(outboxMessage);
    // No SaveChangesAsync here — will be committed together with AppDbContext.SaveChangesAsync
}

// In CauseController
[HttpPost("create")]
public async Task<IActionResult> CreateCause([FromBody] CreateCauseRequest request)
{
  ...
  // Business logic only, no SaveChanges
  var member = await _memberService.EnsureMemberAsync(request.Email);
  var profile = await _profileService.EnsureProfileAsync(member.Id);
  var cause = await _causeService.CreateCauseAsync(profile.Id, request.Title);

  // Instead of AuditDbContext → record Outbox entry (same DB, atomic)
  await _outboxService.QueueAuditAsync("CauseCreated", member.Id);

  // Persist all changes at once
  await _uow.CommitAsync();

}

```

Eliminate all SaveChangesAsync() calls from the service layer; persistence should be handled externally.


Then a Background Service picks up outbox messages and uses AuditService (with AuditDbContext) to persist them:

```csharp
// In OutboxProcessor : BackgroundService
protected override async Task ExecuteAsync(CancellationToken stoppingToken)
{
  ...
  while (!stoppingToken.IsCancellationRequested)
  {
      var messages = await _appDbContext.OutboxMessages
            .Where(m => !m.Processed)
            .ToListAsync();

        foreach (var msg in messages)
        {
            await _auditService.WriteLogAsync(msg.Type, msg.CreatedBy);
            msg.Processed = true;
        }

        await _appDbContext.SaveChangesAsync();
  }      
  ...     
}
```

Now, all related operations occur within the same transaction, while business logic and logging are decoupled, making the code more robust.

## Conclusion

Calling SaveChangesAsync in service layers can lead to multiple transactions, increased latency, and potential inconsistencies, especially with multiple databases. Using a Unit of Work pattern centralizes persistence and ensures atomic operations, while the Outbox pattern with a background worker handles separate databases reliably. This approach maintains data consistency, improves performance, and aligns with best practices for enterprise applications.
Although distributed transactions could also ensure consistency across multiple databases, they come with significant drawbacks: increased latency, added complexity, reduced availability, and limited scalability. The details of this approach will not be elaborated here.