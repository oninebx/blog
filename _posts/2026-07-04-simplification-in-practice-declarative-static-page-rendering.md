---
title: "Simplification in Practice: Declarative Static Page Rendering"
date: 2026-07-04T10:41:10.315Z
toc: true
categories:
  - Frontend
tags:
  - TypeScript
  - React
  - Code Refactoring
---
This work started as a frontend task I took on shortly after joining a new company. The implementation was relatively simple, but it addressed a set of long-standing pain points in how the team built static pages. It was quickly adopted and later became the basis for a broader refactoring of the existing solution.

## Pain Points

The project required building a set of static pages for information display, including elements such as titles, paragraphs, images, lists, tables, videos, and collapsible sections—roughly a dozen content types in total. With a tight deadline and a team of four engineers working in parallel, I observed several recurring pain points in the implementation approach:

- **Every New Page Started from Scratch**

  Even though many pages shared similar layouts, engineers often copied existing implementations and modified them instead of reusing common patterns. As the number of pages grew, so did the amount of duplicated code.

- **Layout and Rendering Were Mixed Together**

  The page structure was written directly in JSX, alongside implementation details. As a result, understanding the overall layout required reading component code rather than simply looking at the content hierarchy.

- **No Consistent Way to Compose Content**
  
  Different engineers naturally built pages in different ways. Similar layouts could have completely different implementations, making the codebase harder to read and maintain.

- **Adding New Content Was More Expensive Than It Should Be**

  Supporting a new content type wasn't just about creating a new component. It often required updating multiple places in the codebase, making seemingly small changes require unnecessary coordination.

- **Content Was Tightly Coupled to React Components**
  
  The content itself existed only as JSX. This meant it couldn't easily be reused, transformed, generated, or validated independently of the rendering logic.

## Design Goals 

### Separation of Page Shell and Content Layer

#### Page Shell(Layout Structure)

The page shell is responsible for the overall structure of the page. It defines where things are rendered, but not what is rendered.

Typical elements include:

- Header
- Footer
- Sidebar
- Navigation layout
- Page-level containers

These elements are relatively stable across different pages and are usually controlled by the application layout system rather than individual page definitions.

In other words, the page shell defines the **frame of the page**.

#### Content Layer (Renderable Content)

The content layer defines the actual content displayed inside the page shell. It is composed of a set of reusable components for rendering content and defining content layout, which can be extended as page requirements evolve.

These components include both basic content elements and layout primitives, such as:

- **Content components (what is shown)**
  - Paragraph
  - Title
  - Image
  - List
  - Table
  - Video
  - Collapse / FAQ

- **Layout components for content composition (how content is arranged)**
  - VerticalStack
  - HorizontalStack
  - Grid

### Separation of Page Definition and Rendering Logic

With the introduction of the content layer, another important separation naturally emerged: **page definition is no longer tied to rendering logic**.

In the previous approach, pages were defined directly using React components, meaning structure and rendering were coupled together. Any change in layout or behavior required modifying the implementation itself.

In the new model, a page is defined purely as data, while rendering is handled independently by a generic rendering system.

#### Page Definition Principles

With the separation of concerns in place, page definitions are treated as pure data structures. To keep the system consistent and predictable, a few key principles are followed when defining pages.

- **Declarative structure**

  Pages describe what to render, not how to render. There is no layout logic or imperative code inside page definitions.

- **Tree-based composition**

  Every page is represented as a hierarchical tree of nodes. Each node can contain children, allowing nested content and layout structures.

- **Type-driven nodes**

  Each node is identified by a type, which determines how it should be rendered. The definition itself remains agnostic of implementation details.

- **Props as configuration only**

  Node props are used purely to express semantic configuration of the content and should not contain any rendering logic or UI implementation details. Where appropriate, children is used not only for nested structure but also for representing simple content, reducing the need for excessive props and following a minimal-property design principle.

**Example: Page Definition**
```json
{
  type: "ArticleLayout",
  title: "Article Sample 1",
  children: [
    {
      type: "heading",
      level: "h1",
      children: "Privacy Policy"
    },
    {
      type: "paragraph",
      children: "This page explains how we handle user data."
    },
    {
      type: "stack",
      direction: "vertical",
      children: [
        {
          type: "heading",
          level: "h2",
          children: "Data Collection"
        },
        {
          type: "paragraph",
          chilren: "We only collect necessary information."
        },
        {
          type: "list",
          items: [
            "Email address",
            "Usage data",
            "Device information"
          ]
        }
      ]
    }
  ]
};
```

#### Rendering Engine Design Principles

The rendering engine is responsible for turning a content tree into actual UI. Its design follows a few key principles to ensure consistency, extensibility, and simplicity.

- **Type-driven mapping layer**

  The renderer is a pure mapping layer that resolves each node’s type into a corresponding component. It does not interpret page structure, content meaning, or business logic, and is only responsible for rendering based on node types.

- **Recursive composition**

  The rendering process is inherently recursive. Each node is rendered independently, and its children are passed down and rendered using the same mechanism.

- **Registry-based extensibility**

  Component resolution is handled through a central registry. Adding a new content type does not require changes to the renderer itself, only a new registration entry.


## Implementation

The implementation is intentionally kept lightweight and closely aligned with the architectural principles described above. The full source code can be found in the accompanying repository: [static renderer](https://github.com/oninebx/static-renderer).

At a high level, the system is built around three core ideas:

- A **content tree** that represents the page as structured data
- A **type-driven rendering engine** that processes each node recursively
- A **component registry** that maps content types to UI implementations

In addition, the system provides a createRoutes utility to associate URL paths with page definitions. This allows pages to be composed and registered in a structured way, while keeping routing concerns separate from the rendering engine itself.

## Conclusion

By separating page definition from rendering, and modeling content as a declarative tree, the system becomes easier to extend and maintain.

In our project, we adopted this engine to manage more than a dozen static pages, which significantly reduced maintenance overhead and improved development efficiency.