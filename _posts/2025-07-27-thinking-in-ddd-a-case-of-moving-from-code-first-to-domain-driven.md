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

## Domain Problem

There is a process in the system where an operator needs to manually verify the data in an account statement file and enter it into the system one by one to generate the corresponding donations. This is a time-consuming and tedious task. Although it only occurs once a month, our customer service colleagues are reluctant to do it. Moreover, as the data in the account statements continues to grow, automating this process has become a necessity. 

### Domain Model from Customer Service

This process stores the user's account statement data from the file into the database and creates corresponding transaction and payment records for each statement, thereby updating the account balance. When the balance exceeds the amount required to create a Donation for a fundraising campaign the user has joined, a Donation is generated accordingly. This domain knowledge from the customer service team can be modeled using the following flowchart.

<div class="mermaid">
flowchart TD
    Start[Start: Read user account statement file]
    Start --> SaveData[Save statement data to database]
    SaveData --> CreateTransaction[Create transaction records for each statement]
    CreateTransaction --> CreatePayment[Create payment records for each statement]
    CreatePayment --> UpdateBalance[Update user account balance]
    UpdateBalance --> CheckCampaigns[Check user's joined fundraising campaigns]
    CheckCampaigns --> CheckBalance{Is balance greater than required amount?}
    
    CheckBalance -- Yes --> CreateDonation[Create Donation for the campaign]
    CreateDonation --> LoopBack[Process next statement or wait for new data]
    
    CheckBalance -- No --> LoopBack
    
    LoopBack --> Start
</div>

### Domain Model from Technical Team

As a programmer, I naturally associate automated processes with batch processing, and believe that writing multiple similar records in batches can lead to performance improvements. As a result, the domain model in my mind has taken shape accordingly.

<div class="mermaid">
flowchart TD
    A[Read user account statements file] --> B[Save statements data to database]
    B --> C[Create transaction records for all statements]
    C --> D[Create payment records for all statements]
    D --> E[Update balance for all user accounts]
    E --> G[Create Donations for all campaigns where the account balance exceeds the required amount.]
</div>

Although this model appears much simpler, it’s not easy to implement. For instance, to enable batch processing, several collections were introduced to store intermediate results, and the rich set of collection operations provided by LINQ did not improve code readability. The beauty of this implementation lies in reading, processing, and saving similar data in a vectorized manner, which leads to higher data processing efficiency. However, the customer service staff are not concerned with efficiency — what matters more to them is whether the data is handled transactionally.

### Transaction-Driven Design

The term "transaction" here borrows the concept from databases to emphasize the integrity of data processing, though the two are not exactly the same. The real-world business scenario is more complex, involving over ten tables spread across four different databases. Only by introducing distributed transactions can true atomicity of data processing be guaranteed. From the perspective of the customer service team, each conversion from an account statement to a donation is considered a transaction. Batch processing, however, breaks this rule, making it difficult to track the processing of individual statement.
The logs added for batch processing also turned out to be too coarse-grained when troubleshooting issues. This awkwardness stems from a common problem: ***the code implementation does not accurately reflect the domain model***. After multiple discussions, we concluded that loading statement data from the file is not part of the transaction and can be handled in batch. However, the rest of the process should follow the principle of treating each account statement as a separate transaction. The adjusted domain model is shown below:

<div class="mermaid">
flowchart TD
    SaveData[Save all statements data to database] -->
    Start[Start: Read user account statement file]
    Start --> CreateTransaction[Create transaction records for each statement]
    CreateTransaction --> CreatePayment[Create payment records for each statement]
    CreatePayment --> UpdateBalance[Update user account balance]
    UpdateBalance --> CheckCampaigns[Check user's joined fundraising campaigns]
    CheckCampaigns --> CheckBalance{Is balance greater than required amount?}
    
    CheckBalance -- Yes --> CreateDonation[Create Donation for the campaign]
    CreateDonation --> LoopBack[Process next statement or wait for new data]
    
    CheckBalance -- No --> LoopBack
    
    LoopBack --> Start
</div>

### Conclusion

In practice, I first implemented the second model above, while the third one became the final version. Fortunately, since much of the business logic code was reusable, the refactoring didn’t take too much time. This experience made me reflect on the importance of the domain model—if the entire team could work under a continuously refined domain model, it would be much more efficient. I’d like to conclude by quoting Eric Evans’ explanation of the role of a domain model, which perfectly captures what I deeply experienced in this case:
The model dictates the form of the design of the heart of the software.
The model is the backbone of a language used by all team members.
The model is distilled knowledge.