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
ASP.NET Core includes a built-in IoC container that natively supports dependency injection. When configuring dependency injection in ASP.NET Core, choosing the correct service lifetime—**Transient, Scoped, or Singleton**—is essential to ensure correct behavior and resource management. The following data inconsistency case, drawn from a real-world project, was caused by an incorrect choice of DI service lifetime.

The project is structured using a layered architecture based on the Controller-Service-Repository pattern. The sample code replicates the key parts of the project code, and the class diagram structure is as follows.