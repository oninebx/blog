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

<﻿div class="mermaid">

graph TD 

A\[Server Processing Chunk 1] --> B\[Write to Response Body] B --> C\[Flush] C --> D\[Client Receives Chunk 1] D --> E\[Server Processing Chunk 2] E --> F\[Write to Response Body] F --> G\[Flush] G --> H\[Client Receives Chunk 2] H --> I\[...]

<﻿/div>

### F﻿etch & Parse Data

### C﻿SS Styling

## C﻿onclusion