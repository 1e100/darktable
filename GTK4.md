# GTK4 Porting Assessment

Overall difficulty: **very high**. Estimated 6–10 weeks of full-time work by someone familiar with both GTK3 and GTK4, plus 2–3 weeks of testing. Several areas require architectural redesign rather than mechanical substitution.

## Scale

- 244 of 1,055 source files include GTK headers
- 16 custom widgets in `src/dtgtk/`, several 1,000–3,500 lines long
- 6,100+ Cairo references, 584 GdkEvent references, 860 GtkTreeView references

## Hard Problems (architectural redesign required)

### 1. Draw signal → GtkSnapshot (~2–3 weeks)

61 `draw` signal connections across 46 files. The GTK4 drawing model is fundamentally different: widgets implement a `snapshot` vfunc rather than connecting to a `draw` signal and receiving a `cairo_t`. The core rendering pipeline is heavily affected:

- `src/views/thumbtable.c` (3,503 lines)
- `src/views/thumbnail.c` (2,489 lines)
- `src/views/culling.c` (2,439 lines)
- `src/dtgtk/range.c` (2,084 lines)

No mechanical conversion exists. Each custom widget must be rewritten to use `GtkSnapshot` and `gtk_snapshot_append_cairo()` (for gradual migration) or native snapshot APIs.

### 2. GtkEventBox removal (~2–3 weeks)

74 references; three custom widgets *inherit* from `GTK_TYPE_EVENT_BOX`, which is entirely removed in GTK4:

- `src/dtgtk/range.c`
- `src/dtgtk/icon.c`
- `src/dtgtk/resetlabel.c`

These must be redesigned as `GTK_TYPE_WIDGET` subclasses, with event handling migrated to `GtkGestureClick`, `GtkEventControllerKey`, `GtkEventControllerMotion`, etc.

### 3. Menu system (~2–3 weeks)

219 `GtkMenu`/`GtkMenuItem` references across 23 files. `GtkMenu` is completely removed in GTK4 — replaced by `GMenu` + `GtkPopoverMenu` with a `GAction`/`GMenuModel` architecture. This is not a drop-in replacement; it requires rethinking how menus are constructed and activated. There is also a custom menu widget at `src/dtgtk/stylemenu.c` that needs full redesign.

Key files: `src/views/darkroom.c`, `src/gui/metadata_view.c`, `src/libs/tagging.c`

### 4. GdkEvent API (~2–3 weeks)

584 total event references; 353 uses of typed event structs (`GdkEventButton`, `GdkEventKey`, `GdkEventScroll`, etc.) across the codebase. GTK4 replaces this with `GdkEvent` accessor functions and moves most event handling to `GtkEventController` subclasses. `gui/gtk.c` alone has 58 such references.

### 5. gtk_dialog_run removal (~1–2 weeks)

56 calls across 22 files. GTK4 removes blocking modal dialogs entirely. Every call site must be converted to an async pattern using the `response` signal and a callback.

## Large but Mechanical

These are high-volume but mostly straightforward substitutions:

| GTK3 API | GTK4 replacement | Count |
|---|---|---|
| `gtk_box_pack_start/end` | `gtk_box_append/prepend` | 486 calls, 47 files |
| `gtk_widget_show/hide` | `gtk_widget_set_visible()` | 465 calls |
| `gtk_container_add` | widget-specific add methods | 134 calls |
| `gtk_widget_show_all` | no equivalent — must recurse manually | 164 calls |
| `gtk_bin_get_child` | widget-specific getters | 99 calls |
| `gtk_container_get_children` | `gtk_widget_get_first_child` + siblings | 35 calls |
| `GdkWindow` / `gtk_widget_get_window` | `GdkSurface` / `gtk_widget_get_surface` | 60 refs |
| `GtkStyleContext` (get/add/remove) | updated API | 116 refs |

Note: `gtk_box_pack_start` expand/fill/padding parameters have no direct equivalent — child properties must be set via `gtk_widget_set_hexpand`, margins, etc.

## Deferred: GtkTreeView

860 references across 26 files (`src/libs/metadata_view.c`, `src/libs/tagging.c`, `src/libs/geotagging.c`, `src/libs/import.c`, etc.). GtkTreeView still exists in GTK4 but is deprecated in favor of `GtkColumnView` + list models. This migration can be deferred without blocking the initial port.

## Suggested Order of Attack

1. **GtkEventBox widgets** — unblocks everything else; these are the deepest base types
2. **Draw signal / snapshot** — high-risk, must be done widget by widget with testing at each step
3. **Event handling** — pervasive but isolatable; tackle alongside widget rewrites
4. **Menu system** — self-contained, can be done in parallel with widget work
5. **Mechanical substitutions** — gtk_box_pack, container_add, show/hide, dialog_run; these can be scripted partially and done last
6. **GtkTreeView modernization** — defer to a follow-up
