---
title: "Decoupling by Design: Implementing an Assessment Mechanism with Events"
date: 2025-10-15T07:32:04.254Z
toc: true
categories:
  - Project Notes
tags:
  - C#
  - .NET
---
This was my latest practical experience in a real-world project, where I addressed several key challenges in implementing the payee compliance assessment flow.

*  clear but general idea: automatically identifying potentially non-compliant payees through a set of rules
* Multiple, distributed rules: non-compliance can arise from rules across processes or domains, which can be freely added or removed.
* Unstable scoring and risk levels: rules are individually scored, and total scores determine risk, with some scoring criteria still undefined.

This is a typical scenario requiring agile development: we need to design a stable structure that can flexibly handle uncertainty, and implement a design that follows OCP and SRP principles. For ease of description, I will refer to this design as the **Assessment Mechanism**. The "Rules" mentioned above will be defined as "**Rubrics**".

## OCP & S﻿RP

**The Open/Closed Principle (OCP)** means that a system should be **open for extension but closed for modification**. In practice, this means we can add new features or behaviors by extending existing code—such as adding new classes, events, or handlers—without changing the stable core logic. This reduces the risk of breaking existing functionality and makes the system easier to evolve.

Each Rubric’s scoring logic is implemented and validated individually, then integrated into the Assessment Mechanism. Existing logic remains unchanged, while new Rubric logic can be added freely — illustrating the Open/Closed Principle (OCP) in action.