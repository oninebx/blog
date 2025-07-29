---
title: "Thinking in DDD: A Case of Moving from Code-First to Domain-Driven"
date: 2025-07-27T21:03:46.390Z
toc: true
categories:
  - Architecture
tags:
  - System Design
  - C#
  - Code Refactoring
---
The domain of a software program is the subject area of the user's activity or interest that it supports. Every day, we solve problems within the domain, even though we rarely mention it at work. Each person carries a partial and imperfect domain model in their mind, but in a well-functioning team, the domain knowledge should be complete—just distributed among different team members. Building a unified and agreed-upon domain model can effectively bridge the domain knowledge gaps among team members. An efficient model should be able to shape the software’s core design, linking analysis to implementation and aiding maintenance by making the code understandable through the model.

I came across this in Eric Evans' book, and it was validated in a recent programming practice.

## D﻿omain Problem

There is a process in the system where an operator needs to manually verify the data in an account statement file and enter it into the system one by one to generate the corresponding donations. This is a time-consuming and tedious task. Although it only occurs once a month, our customer service colleagues are reluctant to do it. Moreover, as the data in the account statements continues to grow, automating this process has become a necessity. This process stores the user's account statement data from the file into the database and creates corresponding transaction and payment records for each statement, thereby updating the account balance. When the balance exceeds the amount required to create a Donation for a fundraising campaign the user has joined, a Donation is generated accordingly. As shown in the diagram below: