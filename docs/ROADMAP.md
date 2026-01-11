# Pathd Roadmap

## Overview

Pathd is a filesystem first, policy driven spatial shell built on drawfs. This roadmap tracks near term deliverables, medium term evolution, and long term alignment with drawfs kernel capabilities.

## Backlog

### P0 Hardening and correctness

* Auto rename on conflict policy using suffix `~1`, `~2`, without overwrite
* Resolve and block recursive moves, directory into its own subtree
* Optional path canonicalization gate using realpath
* Unit tests for move policy, same filesystem, cross filesystem, conflicts
* Unit tests for row hit testing and scroll behavior

### P1 Input pipeline completion

* Replace stdin dev backend with a real FreeBSD input backend
* Modifier keys mapping
* Keyboard equivalents for drag operations
* Configurable double click timing
* Pointer hover feedback without drag

### P2 View and UX expansion

* List Details view, size, mtime, mode
* Per directory view policy stored in a dotfile
* Sort mode toggles, name, size, mtime
* Incremental search within directory
* Indicators for symlinks and special files

### P3 Multi view and window propagation

* Multiple views per session, each with its own cwd
* Focus routing across multiple views and surfaces
* Window propagation, child view requests bubble to root
* Stacking and tiling policies handled by Pathd

### P4 Filesystem operations policy

* Explicit copy policy, opt in and cross filesystem
* Recursive directory copy with progress reporting
* Delete policy with confirmation and trash abstraction
* Batch operations with job queue

### P5 drawfs integration futures

* drawfs delivered input events
* Optional kernel assisted damage tracking
* Secure focus enforcement at kernel boundary
* Multiple displays per session

## Non goals

* No implicit cross filesystem copy without explicit policy
* No compositor logic in Pathd
* No hidden background filesystem mutations
* No policy embedded in the drawfs kernel
