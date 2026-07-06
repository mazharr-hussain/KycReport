# Word Exports

Pre-generated `.docx` versions of the V2 and V3 business guides, with all diagrams embedded as static images.

- `V2_As-Is_Process.docx` — V2 As-Is Process Guide
- `V3_Best_Practice_Process.docx` — V3 Best Practice Process Guide

**These are generated files, not source.** If `docs/V2_BUS_AsIs_Process.md`, `docs/V3_BUS_BestPractice.md`, or any of the referenced `.drawio` files change, regenerate with:

```
python3 scripts/render_drawio.py docs/diagrams/drawio/asis-process.drawio /tmp/rendered/asis-process
python3 scripts/render_drawio.py docs/diagrams/drawio/best-practice-e2e.drawio /tmp/rendered/best-practice-e2e
python3 scripts/render_drawio.py docs/diagrams/drawio/approval-workflow.drawio /tmp/rendered/approval-workflow
python3 scripts/render_drawio.py docs/diagrams/drawio/intake-flow.drawio /tmp/rendered/intake-flow

python3 scripts/md_to_docx.py docs/V2_BUS_AsIs_Process.md /tmp/rendered docs/exports/V2_As-Is_Process.docx "V2 — As-Is Process Guide"
python3 scripts/md_to_docx.py docs/V3_BUS_BestPractice.md /tmp/rendered docs/exports/V3_Best_Practice_Process.docx "V3 — Best Practice Process Guide"
```

See `scripts/README.md` for requirements and details.
