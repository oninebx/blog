---
title: Streaming Progress Updates in Long-Running ASP.NET Core Requests
date: 2025-07-13T07:35:18.928Z
toc: true
categories:
  - Project Notes
tags:
  - ASP.NET
  - C#
  - JavaScript
---
This is a feature recently implemented in our project to enhance the user experience. Some time-consuming requests, such as when the backend receives a file and processes its data according to business rules, often require users to wait for the processing to complete before performing other actions. Any operation that causes the interface to refresh during this process could interrupt the workflow and result in incorrect data. Additionally, for time-consuming requests, the frontend can appear "frozen," which easily leads to user misoperations.

Therefore, when I suggested implementing a message window to display progress, error messages during processing, and completion prompts while blocking user interactions, the entire team immediately agreed. With the help of AI, this feature was quickly implemented, as shown in the image below.

[S﻿ource Code](https://github.com/oninebx/Think2Code/tree/main/DotNet)

![](/uploads/streamingprocess.gif)

## T﻿echnologies Involved

### S﻿treaming Response



````mermaid
```mermaid
  graph TD
    subgraph Server [Server]
      direction LR
      subgraph Chunk1 [Chunk1]
        A1[Server Processing Chunk 1] --> B1[Write to Response Body] --> C1[Flush]
      end 
      subgraph Chunk2[Chunk2]
        A2[Server Processing Chunk 2] --> B2[Write to Response Body] --> C2[Flush]
      end
      subgraph Chunk3 [...]
        A3[Server Processing Chunk ...] --> B3[Write to Response Body] --> C3[Flush]
      end
    end
    subgraph Client [Client]
    C1 --> D1[Client Receives Chunk 1]
    C2 --> D2[Client Receives Chunk 2]
    C3 --> D3[Client Receives Chunk ...]
    end
```
````

### F﻿etch & Parse Data

### C﻿SS Styling

## C﻿onclusion