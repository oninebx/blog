---
title: "From Confusion to Clarity: Resolving Scoped and Singleton Injection Conflicts"
date: 2025-08-01T10:12:00.595Z
toc: true
categories:
  - Project-Notes
tags:
  - Entity Framework
  - ASP.NET
  - C#
  - Code Refactoring
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

The simplified code is easier to understand, but it will throw exceptions at runtime when multiple concurrent requests of the same type occur.

***InvalidOperationException: An attempt was made to use the model while it was being created. A DbContext instance cannot be used inside 'OnModelCreating' in any way that makes use of the model that is being created.***

## Mistrust of the running code

After googling the issue, I found the answer on [stackoverflow](https://stackoverflow.com/questions/54834970/system-invalidoperationexception-an-attempt-was-made-to-use-the-context-while-i). The crucial message is as follows.

* Scoped services aren't directly or indirectly injected into singletons.

Then I came across another piece of code that puzzled me, as shown below.

```csharp
  ...
  services.AddDbContextPool<CoreDbContext>(o => o.UseSqlServer(Configuration.GetConnectionString("Core")));
  ...
   services.AddSingleton<IMemberService, MemberService>();
   services.AddSingleton<IAuditService, AuditService>();
  ...
```

This piece of code was written in the early stages of the project, so no one questioned or modified it. As a result, when new service instances were injected, they followed this default convention. Consequently, many services and repositories in the project were registered with a Singleton lifetime.  At that moment, I began to question the validity of the old code and became curious about whether mixing dependencies with different lifetimes in dependency injection was a good approach.

## Understanding the Problem and How to Fix It Right

`CoreDbContext` is registered with a scoped lifetime using `AddDbContextPool`, but instances of this type are injected into services like `MemberService` and `AuditService`, which are registered with a singleton lifetime. This kind of injection has been prohibited since .NET Core 3.0 and will result in a compile-time error. Unfortunately, our project is built on .NET Core 2.2, which does not perform dependency injection lifetime conflict checks at compile time.

The developer who implement the `AuditService` was unaware of the implications of injecting a scoped service into a singleton. Instead of addressing the root issue, they worked around it with two questionable code patterns—explicitly passing a scoped `CoreDbContext` into each `Record` method, thereby sidestepping the injection conflict.

Based on the above analysis, when I registered `MemberService` and `AuditService` with a scoped lifetime, the exception magically disappeared. 

```
...
   services.AddScoped<IMemberService, MemberService>();
   services.AddScoped<IAuditService, AuditService>();
  ...
```

### Protect the code from being polluted

.NET provides configuration options to enforce validation of dependency injection lifetimes at build time. To prevent developers from introducing improper dependencies, we added the following code to our project. Of course, this option is enabled by default in versions 3.0 and later.

```csharp
// Program.cs

builder.Host.UseDefaultServiceProvider(options =>
{
    options.ValidateScopes = true;
    options.ValidateOnBuild = true;
});
```