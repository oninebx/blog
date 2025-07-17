---
title: Pitfalls of Using ref Variables in LINQ Select with Multiple Enumerations
date: 2025-07-14T13:23:08.043Z
toc: true
categories:
  - Project Notes
tags:
  - LINQ
  - C#
  - Debugging
---
I work with LINQ almost every day and frequently deal with various operations based on IEnumerable. Since I’ve always found it convenient to use, I never really dug into the principles behind IEnumerable. Recently, I encountered a subtle issue in a project that was caused by the number of enumerations and the use of ref variables inside the enumeration method. This blog post will analyze the cause of the problem and the corresponding solutions.