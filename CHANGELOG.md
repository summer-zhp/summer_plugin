# CHANGELOG

## 1.0.2

Changelog formatting update: rewritten from Chinese to English to improve readability on pub.dev.

## 1.0.1

No functional code changes in this release. The changelog format itself was updated — the previous list-style version entries were rewritten into flowing narrative paragraphs, making it easier to follow the evolution of the component across releases. This is a documentation-only formatting improvement.

## 1.0.0

First stable release. Introduces the core data table component `SummerDataTable`. Built on a vertical `ListView.builder` for virtual scrolling and a single horizontal `RenderBox` for panning, it achieves solid rendering performance and maintainability without a custom paint loop. Ships with a comprehensive set of commonly needed features out of the box:

- Fixed header row and pinned left/right columns
- Single- and multi-column sorting (Shift-click to stack, with priority indicators)
- Column filter dropdowns
- Row selection via checkbox or radio
- Expandable row detail panels
- Column width drag-to-resize
- Text ellipsis with tooltip
- Tree and hierarchical data support
- Grouped (merged) table headers
- Loading, empty, and pagination states
- Theme-based style customization
