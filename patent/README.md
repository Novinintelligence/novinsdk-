# Patent Package README

This folder contains a ready-to-file Provisional Patent Application (PPA) package.

## Contents
- `Provisional_Patent_Application_Draft.md` — Full spec (export to PDF)
- `Claims_Draft.md` — Optional claims for support (not required for PPA)
- `SB16_Cover_Sheet_Prefill.md` — Fields to copy into USPTO Patent Center cover sheet
- `Drawings/*.mmd` — Mermaid sources for figures (export to SVG/PDF)
- `DOCKET.md` — Priority deadlines

## How to Export

### Drawings (Mermaid → SVG/PDF)
- Option A: Use an online Mermaid renderer and export as SVG/PDF.
- Option B: CLI with `@mermaid-js/mermaid-cli` (mmdc):
```bash
npm i -g @mermaid-js/mermaid-cli
mmdc -i Drawings/Fig1_System_Block.mmd -o Drawings/Fig1_System_Block.svg
mmdc -i Drawings/Fig2_Processing_Pipeline.mmd -o Drawings/Fig2_Processing_Pipeline.svg
mmdc -i Drawings/Fig3_Event_Sequence.mmd -o Drawings/Fig3_Event_Sequence.svg
mmdc -i Drawings/Fig4_Bayesian_Fusion.mmd -o Drawings/Fig4_Bayesian_Fusion.svg
mmdc -i Drawings/Fig5_Explanation_Engine.mmd -o Drawings/Fig5_Explanation_Engine.svg
```

### Spec (Markdown → PDF)
- Option A: Use a Markdown editor (e.g., VS Code) to export as PDF.
- Option B: `pandoc`:
```bash
pandoc Provisional_Patent_Application_Draft.md -o Provisional_Patent_Application_Draft.pdf
```

## Filing Steps (USPTO Patent Center)
1. Create/Sign in to USPTO.gov account (2FA enabled).
2. Patent Center → New Submission → Provisional Application.
3. Upload: `Provisional_Patent_Application_Draft.pdf` and figure PDFs/SVGs.
4. Fill SB/16 cover sheet (or upload the filled PDF) and select fee (Micro/Small/Standard).
5. Review, sign, and submit. Save filing receipt and application number.
6. Update `DOCKET.md` with filing date and docket 12-month deadline.

## Legal Notes
- Provisional does NOT require claims or formal drawings, but enabling detail is essential.
- Public disclosure before filing may affect foreign rights; US has 1-year grace period.
- Fees change: verify current USPTO fee schedule before filing.
- This package is not legal advice; consult a patent attorney to strengthen claims.
