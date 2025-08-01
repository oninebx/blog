---
title: "Hidden Pitfalls in EF Core: When DI Lifetime Breaks Transaction Consistency"
date: 2025-08-01T10:12:00.595Z
toc: true
categories:
  - Project Notes
tags:
  - Entity Framework
  - ASP.NET
  - C#
---
As one of the built-in core features of the .NET development platform, **Inversion of Control (IoC)** or **Dependency Injection (DI)** enables flexible, testable, and loosely coupled code by delegating the creation and management of dependencies to a centralized framework, improving maintainability and scalability. We can see it used in almost all ASP.NET Core projects, and may be familiar with the concept of DI object lifetimes. However, when adding a new dependency, we tend to follow similar existing code in the project without carefully considering whether the chosen lifetime is appropriate. The following case is a real-world example where such habitual thinking led to a data inconsistency issue.