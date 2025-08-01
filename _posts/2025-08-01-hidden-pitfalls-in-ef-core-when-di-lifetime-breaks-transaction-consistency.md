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
ASP.NET Core includes a built-in IoC container that natively supports dependency injection. We can see it used in almost all ASP.NET Core projects, and may be familiar with the concept of DI object lifetimes. When configuring dependency injection in ASP.NET Core, choosing the correct service lifetime—**Transient, Scoped, or Singleton**—is essential to ensure correct behavior and resource management. The data consistency problem illustrated below was the result of incorrectly configuring the service lifetime.