# Local changes to pdfrx 1.3.5

Upstream: https://github.com/espresso3389/pdfrx, published package 1.3.5.
The original MIT license is preserved in LICENSE.

The deferred partial renderer now resolves the scale and visible rectangle at
the same instant. A request queued while zoomed in must not use its old scale
with the larger visible rectangle after returning to fit-to-page. Partial work
and images are canceled/released when the base image is sufficient. After image
conversion, canceled or unmounted requests dispose their new image.

Cache eviction checks the total against the budget before removing a page,
preserving reusable page images when memory use is already below the limit.

Set AUDIT_PDF_RENDER=true at compilation to log deferred request dimensions and
scale changes for device validation. This logging is disabled by default.

Platform sources are unchanged. Generated .lib and .cxx directories are local
build artifacts and excluded from version control. Keep this fork until an
upstream replacement has passed the same device regression scenario.
