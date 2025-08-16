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

## P﻿roblem

The problematic code is used to convert the user's recharged account balance into fixed-amount donations. Below is a partial code snippet.

```csharp
 
 ... 
 var amount = balance;
 var totalDonations = new List<Donation>();
 var donations = targets.Select(t => CreateDonation(t, ref amount))
     .Where(d => d.Amount != 0);
 if(donations.Any())
 {
   totalDonations.AddRange(donations);
   ...
 }
 else
 {
   ...
 }
...
  
 private Donation CreateDonation(Target target, ref decimal amount)
 {
  ...
   var donation = new Donation
   {
     Amount = 0
   };
   var remainAmount = amount - target.Amount;
   if(remainAmount >= 0)
   {
     donation = new Donation
     {
       ...
       Amount = target.Amount,
       ...
     };
   }
  ...
  return donation;
 }
```

The logic of this code is straightforward: when the balance is not less than the target donation amount, a donation will be created and returned based on the target amount, and the balance will then be reduced by that target amount. To facilitate LINQ collection operations, the CreateDonation method always returns a Donation, and valid donations are then filtered by checking if the Amount is greater than 0.

his code is not robust and sometimes fails to generate a Donation based on the specified conditions.

## A﻿nalysis

Deferred execution is one of the core features of `IEnumerable` and is widely used in LINQ queries. This feature separates the definition from the execution, meaning the defined logic is only executed during each iteration. As shown in the code above, the logic inside the `CreateDonation` method is executed once on each iteration.

If the data source that the enumeration depends on changes during execution, each iteration may produce different results. This is one of the side effects of the deferred execution feature of `IEnumerable.`Unfortunately, the code snippet above happens to meet all the conditions that lead to such side effects. `Amount` is the data source that the enumeration depends on, and since it is passed as a reference type parameter, it can be modified during execution. Both `donations.Any()` and `TotalDonations.AddRange(donations)` trigger enumeration traversal, meaning the `donations` enumeration is iterated twice. Although the first traversal triggered by the `Any` method generates donations using the correct `Amount` value, the traversal during `AddRange` creates only invalid donations because by then `Amount` has become 0, resulting in `donation.Amount = 0`. Consequently, all these donations are filtered out.

## S﻿olution

After identifying the cause, the solution to this problem is straightforward: ensure that the `donations` enumeration is traversed only once by immediately calling the `ToList()` method after its definition to materialize the enumeration. The resulting materialized collection will then contain the valid donations.

```csharp
...
var donations = targets.Select(t => CreateDonation(t, ref amount))
     .Where(d => d.Amount != 0).ToList();
...
```