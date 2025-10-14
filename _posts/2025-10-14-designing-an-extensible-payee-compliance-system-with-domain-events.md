---
title: Designing an Extensible Payee Compliance System with Domain Events
date: 2025-10-13T19:51:32.807Z
toc: true
categories:
  - Backend
  - Project Notes
tags:
  - C#
  - .NET
---
This was my most recent hands-on experience in a real project, and it freed me from the following pain points.

* A concrete idea: automatically identifying potentially non-compliant payees through a set of rules
* Multiple, distributed rules: non-compliance can arise from rules across processes or domains, which can be freely added or removed.
* Unstable scoring and risk levels: rules are individually scored, and total scores determine risk, with some scoring criteria still undefined.

This is a typical scenario requiring agile development: we need to design a stable structure that can flexibly handle uncertainty, implementing a design that is open for extension but closed for modification. For ease of description, I will refer to this design as the **Assessment Mechanism**.