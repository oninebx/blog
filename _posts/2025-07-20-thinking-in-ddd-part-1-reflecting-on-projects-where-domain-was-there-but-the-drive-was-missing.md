---
title: "Thinking in DDD: Starting with Lessons from Projects That Missed the Drive"
date: 2025-07-20T10:24:12.016Z
toc: true
categories:
  - Architecture
tags:
  - System Design
  - Code Refactoring
---
In this article, I’ll list a few of the headaches I’ve encountered in recent projects — some of which may have something to do with DDD. There were certainly domain-related elements in the projects, but they didn’t actually drive me to take action. Perhaps these problems are what motivate me to finally read *Domain-Driven Design: Tackling Complexity in the Heart of Software*.

## Technical Debts

Since the year before last, the product’s services started experiencing page crashes during traffic peaks, which negatively impacted the company. The technical team conducted weeks of load testing using JMeter and ultimately concluded that the issue was caused by caching database entity objects, which were several times larger than their equivalent DTOs. When the program deserialized these entities to create object instances, it consumed significantly more CPU and memory resources. As traffic scaled up, the service eventually crashed.

Fixing this problem would be extremely costly, so it was categorized as technical debt and had to be put on hold — the design was completed in the early stage of the project, and many features were built on top of it.With that lesson learned, the team clarified the boundaries between database entities and DTOs, avoiding their cross-layer use. However, a few months later, new problems emerged: a large number of bloated service-layer objects and arbitrarily defined DTOs were being created. For example, a single service method might implement business logic spanning multiple domains and eventually return a DTO tailored to just one business scenario.

I was certain we were creating new technical debt, as these implementations resembled procedural programming wrapped in an object-oriented shell — making them hard to reuse. Perhaps everyone has a mental model that guides their coding, but these models are neither aligned nor made explicit.

Additionally, upgrading the development platform has been a persistent headache. We are maintaining code that has been running for over 10 years — with highly complex dependencies between projects and different platform versions, ranging from .NET Framework 4.x to .NET Core 3.x and .NET 6. We've always wanted to upgrade to a higher .NET version to ensure long-term support, but in the end, the amount of code that would need to be changed has made it impractical.

The inability to upgrade old code poses a risk — as related resources diminish, the cost of maintenance will keep rising. Why did we end up creating such a complex codebase that makes refactoring so costly? Perhaps what we need is a healthy model to guide project structuring, reduce dependency complexity, and ensure that refactoring remains feasible at any time.

## Rediscover ‘Domain’

I’ve read a few chapters of that book on and off, but stopped because I couldn’t apply it in my work. Now that the new leadership has evaluated the technical debt and is considering a project rebuild, addressing these issues has become a priority. This actually aligns with a skill I’ve been honing — using expertise to simplify complexity and uncover the real drivers behind software design.

In various codebases, I’ve seen projects named **Domain**, but I’ve never truly felt any driving force coming from them. In fact, these domain elements are becoming increasingly irrelevant in the code — not only failing to drive the design but sometimes even feeling like burdens we can’t shake off. Perhaps they’ve always carried some force, but after the programmers who designed them left, no one knows how to sense that force or navigate in the right direction.

I’ll continue updating this blog series until DDD helps me solve these problems.

## Rough﻿ Plan

I will start from scratch to design and implement a simple crowdfunding platform called **Simple Fundraising**, which aligns with the domain I’m currently working in. If I get involved in the project rebuild, these designs might even come in handy.

This platform will support users in completing a simple yet complete crowdfunding process. The next chapter will begin with a discussion on **Ubiquitous Language** and use it to describe the Simple Fundraising platform.