# Inbox Item Page Issue

## 1. Understand The Problem

- What do we already know from the current editor/test/output context?
- What would count as a successful next step?

### What exact behavior, question, or change are we trying to handle?

- I cannot see the currently opened inbox item.
- When having an already opened inbox item and going to unread the page flickers as it rerenders but it does not recognize that we are already viewing an unread item.
- Marking an item as read while unread does close the reading view, but instead it should only be removed from the list. This is especially confusing when going back to read as it shown again, but now I have lost where I am within the list. 
- The page does not properly paginate
- When opening an existing item with id I don't know which item it was
- The scrollbar looks broken.

I want to fix the annoying rerender behavior.

### What do we already know from the current editor/test/output context?
The page uses signals and does a new request in between switching the filters activating the unread filter. We must therefore use a heurstic to decide rerender by using the already opened item. 



## 2. Devise A Plan

- Which one assumption should we test first?
- What is the smallest observation that could falsify it?
- What do we predict before inspecting or running anything?

## 3. Carry Out The Plan

- Probe:
- Expected:
- Actual:
- Notes:

## 4. Look Back

- What changed in our model?
- What is now known, assumed, or still open?
- What is the next smallest step?
