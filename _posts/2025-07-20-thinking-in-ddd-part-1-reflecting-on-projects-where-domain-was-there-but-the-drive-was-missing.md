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
As a widely recognized guiding philosophy for architectural design, DDD is a skill I’ve always wanted to master. I once read a few chapters of *Domain-Driven Design: Tackling Complexity in the Heart of Software*, but I stopped shortly after. The book's content is not difficult to understand, but it requires practice in the project to internalize the knowledge.

In my recent projects, I’m quite certain that I’ve been working within the defined domain of the project, as I’ve encountered various things named with “Domain.” However, I didn’t feel any real driving force coming from them.

Since the “Domain” has come knocking, I think it’s time to revisit and internalize DDD. I plan to finish reading the book mentioned above and apply its insights to restore the domain-driven force that should exist in projects. As the first piece in my *Thinking in DDD* series, this article won’t dive into specific technologies. Instead, it’s more of a reflection — or rather, a rant — on the pain points I’ve encountered in past projects. This has always been my original motivation for learning and adopting new technologies.

## Technical Debts

Technical debt exists throughout the entire project lifecycle, but by the time a team becomes aware of it, it has usually shifted from being implicit to explicit, turning into a trouble that can no longer be ignored. I recall that when I was still in China, my colleagues and I frequently complained about the chaos of the project code. Although we were working with technical debt every day, only a few developers had experience in paying it down. Frequent job-hopping and short-lived projects allowed many programmers to avoid dealing with these debts simply. But in New Zealand, the situation is somewhat different. The projects I’ve been involved in have been running for over 10 years, and there are quite a few developers who have been serving the same company for 5 or even more than 10 years. Naturally, they also have to face the ever-accumulating technical debt.

### 'Diverse' Frameworks in monolithic architecture

#### **Version Diversity**

A complete solution is often composed of projects created at different times, so the coexistence of multiple framework versions is a common issue. Some large development platforms, like .NET or J2EE, are robust enough to provide compatibility support. Therefore, upgrading frameworks may be troublesome, but it’s feasible. Moreover, trying to prevent the use of multiple versions isn’t wise, because the cost of maintaining outdated technologies will only increase as related resources diminish. The escalating upgrade costs caused by version diversity across multiple projects are a real headache.

### Bloated classes in unclear layers

### Over-design and under-design in business implementation