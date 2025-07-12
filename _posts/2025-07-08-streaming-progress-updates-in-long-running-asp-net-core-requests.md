---
title: Streaming Progress Updates in Long-Running ASP.NET Core Requests
date: 2025-07-12T09:34:07.681Z
toc: true
categories:
  - Full-Stack Notes
tags:
  - ASP.NET
  - C#
  - JavaScript
---
Last week, I implemented a feature in the project that processes data after a file is uploaded. I noticed that when the data volume is large, the interface appears to freeze, which can easily lead to user errors, such as clicking other buttons and disrupting the processing flow.

![](/uploads/streamingprocess.gif)

# T﻿itle

D﻿raft