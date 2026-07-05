# draw.io Source Files

This folder contains the editable draw.io source files for all process diagrams.

## How to Edit

**Option 1 — Browser (no install needed)**  
1. Go to [app.diagrams.net](https://app.diagrams.net)
2. Open → GitHub → connect to this repo
3. Browse to this folder and open a `.drawio` file

**Option 2 — VS Code Extension**  
1. Install the [draw.io Integration](https://marketplace.visualstudio.com/items?itemName=hediet.vscode-drawio) extension
2. Open any `.drawio` file — it opens as an interactive diagram editor
3. Save to commit the XML source back to Git

**Option 3 — Desktop App**  
1. Download from [get.diagrams.net](https://get.diagrams.net)
2. Open `.drawio` files directly

## Export for MkDocs

When you update a diagram, export it as **SVG** (File → Export As → SVG) and save it alongside the `.drawio` file. The SVG is what renders in the documentation site.

## Files in This Folder

| File | Pages | Diagram |
|---|---|---|
| `intake-flow.drawio` | 1 | Intake and document validation (To-Be) |
| `approval-workflow.drawio` | 3 | Approval state machine, routing rules, delegation (To-Be) |
| `best-practice-e2e.drawio` | 9 | High-level map + per-phase detail, Phases 0–8, plus risk panel (To-Be) |
| `asis-process.drawio` | 8 | System boundary, one-page overview, and per-phase detail for the current manual process (As-Is) |

This is a business-only, As-Is/To-Be branch — `kyc-necessity.drawio` and `apex-architecture.drawio` (V4-specific) were removed from this scope. They still exist on `main`.

Files with more than 1 page use the page selector in the diagram viewer toolbar (top-right of the embedded diagram) to switch pages.
