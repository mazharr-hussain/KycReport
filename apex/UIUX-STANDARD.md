# KYC Compliance Platform – UI/UX Standard

Version 1.0 · applies to every page of app 134 · Universal Theme, **Redwood Light** only

This is the design standard every screen is built and reviewed against. It is written for the people who use the
app all day (requesters, compliance officers, approvers, administrators): a compliance tool must let them **find the
risk, understand the record and act on it** with the least reading, scrolling and clicking.

---

## 1. Principles

| # | Principle | What it means on screen |
|---|---|---|
| P1 | **Task first** | Every page answers: *what is this, what state is it in, what do I need to do?* – in the first screen, without scrolling. |
| P2 | **Show risk, hide noise** | Status, risk, overdue, critical answers and matches are visual (badges, colour, icons). Empty, default or technical values are hidden. |
| P3 | **Scan, don't read** | Short labels, label-above-value pairs, grouped content, no explanatory paragraphs on the page. |
| P4 | **One way of doing one thing** | The same component, wording and position for the same job on every screen (lists, records, forms, actions). |
| P5 | **Progressive disclosure** | Summary first, detail on demand (sections, tabs, drawers, "View all"). |
| P6 | **Safe actions** | The primary action is obvious, destructive actions are separated and confirmed, nothing is lost silently. |
| P7 | **Accessible by default** | WCAG 2.2 AA: contrast, keyboard, focus, labels, never colour alone. |
| P8 | **OOTB first** | Universal Theme templates and template options first; one small app CSS file for the rest. No per-page styling. |

---

## 2. Foundations

### 2.1 Typography

One type scale for the whole app (Redwood font, `Oracle Sans` / system fallback).

| Token | Size / weight | Use |
|---|---|---|
| `page-title` | 26px / 700 | Page title (title bar) |
| `section-title` | 20px / 700, on a shaded header strip with a 4px dark left accent | Region and section titles |
| `group-title` | 16px / 700, 2px divider under it | Field groups inside a section (Identity, Contact) |
| `card-title` | 16px / 600 | Header card title, card titles, dialog titles |
| `body` | **14px** / 400 | All data, table cells, values, form input text |
| `value` | 15px / 700, dark | Values in a record grid and answers; label above in 13px bold dark grey, value larger and darker so it stands out |
| `label` | 13px / 600, dark grey `#4a4541` | Field labels, question text, tile labels |
| `column-header` | 14px / 700, dark text on a darker grey row `#e7e4e0` | Table column headers |
| `meta` | 12px / 400, grey | Secondary info only: timestamps under a value, party number under a name, hints. **Never** for primary data. |
| `kpi` | 32px / 600 | Numbers on KPI cards |

Rules: nothing the user must read is below 12px; data is never smaller than 14px; line height 1.45 for text, 1.25 for
titles; headings and labels are always bolder and darker than the data they introduce, so the structure is clear at a glance; no ALL-CAPS text (emails are shown in lower case).

### 2.2 Colour

Redwood Light palette only (UT CSS variables). Colour carries **meaning**, never decoration.

| Role | Use | UT class / variable |
|---|---|---|
| Neutral | Text, borders, Draft/Cancelled | `u-color-*` neutral, `--ut-body-text-color` |
| Info (blue) | In progress, active, links | `u-info` |
| Success (green) | Approved, verified, no match, compliant | `u-success` |
| Warning (amber) | Waiting on someone, information needed, due soon, potential match, medium risk | `u-warning` |
| Danger (red) | Rejected, overdue, confirmed match, high risk, critical answer, errors | `u-danger` |

Text contrast ≥ 4.5:1, large text and icons ≥ 3:1. Colour is always paired with text or an icon.

### 2.3 Spacing and layout

- 8px grid: spacing 4 / 8 / 16 / 24 / 32px. Region padding 16–24px, gap between regions 16px.
- Content uses the full width for lists; **forms and record grids have a max readable width** (forms ≈ 960px).
- 12-column grid; record fields use 3 columns ≥ 1200px, 2 columns 768–1199px, 1 column below 768px.
- Region template: **Standard** with no extra shadows; a region without a title uses **Blank with Attributes**.
- No decorative imagery: the Redwood **pattern strip under the title bar is turned off** on every page (plain title bar).

### 2.4 Icons

Font APEX icons only, outline style, 16px inline / 24px on cards. An icon never stands alone for an action without a
tooltip and an accessible label.

### 2.5 Formats

| Data | Format | Example |
|---|---|---|
| Date | `DD-MON-YYYY` | 04-OCT-2026 |
| Date and time | `DD-MON-YYYY HH24:MI` | 04-OCT-2026 06:04 |
| Recent activity | relative, exact date on hover | 2 days ago |
| Amounts | grouped, 2 decimals, right aligned | 1,250,000.00 |
| Percent | integer + % | 78% |
| People | **employee name** (`xxfnd_employees.full_name`); on hover a small card: Name · Employee no. (`fusion_person_number`) · Department (`department_name`) · User name (`user_name`); "System" for automatic actions; user name shown when no employee record exists | Shahid Hussain |
| Empty | blank cell (lists); hidden field (records) | — |
| Yes/No | badge or icon, never the words alone in a dense table | ✓ KYC |

---

## 3. Page anatomy

Every page follows the same skeleton, top to bottom:

1. **Title bar** – breadcrumb + page title. Primary page action (e.g. *Create Request*) on the right.
   Plain bar, no image strip. "Back" is never a button: the breadcrumb is the way back.
2. **Context** – on record pages the **header card** (§5); on lists the **report tabs / filters** (§4).
3. **Content** – one main task area. Long records are split into **sections or tabs**, never one long stack.
4. **Action bar** – on record and form pages, a **sticky footer bar** (§7).

Page types used by the app:

| Type | Pages | Pattern |
|---|---|---|
| Dashboard | 1 Home, 230 Executive Dashboard | KPI cards + worklist (§8) |
| List | 20, 30, 40, 200, 210, 220, 221, admin lists | Interactive Report with saved tabs (§4) |
| Record view | 21, 205, 211 (read-only), 31 | Header card + grid + sections (§5) |
| Record approval | 206, 211 (approver) | Record view + decision panel (§7.3) |
| Form / edit | 22–25, admin forms | Form standard (§6) in a drawer or page |
| Wizard | 201 → 204 → 202 → 203 | Wizard progress + form standard (§6.5) |

---

## 4. Lists (Interactive Reports)

### 4.1 Structure
- **Saved report tabs above the table** (IR "primary + public saved reports" shown as tabs), e.g.
  *My Requests · Pending My Action · Information Needed · All*. The default report shows the user's own work. No
  pre-set filter chip is visible on the default report.
- Full-width search field; Actions menu keeps Columns, Filter, Sort, Download (CSV/Excel), Save Report.
- **6–8 default columns.** Others stay available under Actions › Columns.
- Column order: **identifier (link) → subject → status → who/where it is → when → related record → row actions**.

### 4.2 Table style
- Header row: 14px/700, dark text on a darker grey row, 40px high, sticky on scroll.
- Data rows: 14px, 44px min height, 1px light divider, hover highlight, no zebra stripes.
- Alignment: text left, numbers/amounts right, badges and dates left (consistent column start).
- Identifier column is the **link to the record**; related records (Case, Party) are links too.
- Secondary detail goes **under** the main value in `meta` style (e.g. party number under the name), not into an
  extra column.
- Long free text wraps (max 2 lines with ellipsis, full text on hover).
- Pagination: 25 rows; the row count and pagination are hidden when everything fits on one page.

### 4.3 Status and flags
Status is always a **badge** (§9). Booleans are a small icon or badge, shown only when true where possible.

### 4.4 Row actions
- One **row actions menu (⋮)** in the last column, items in a fixed order: *View · Edit · …business actions… ·
  destructive action last (e.g. Withdraw)*; items appear only when allowed (privilege + status).
- No inline text links for actions next to data.

### 4.5 Empty states
A short sentence and, when the user may create, one button: *"No requests yet. Create Request"*. With a filter:
*"No requests match this filter. Clear filter"*.

---

## 5. Record pages

### 5.1 Header card
The first thing on every record page:

```
┌──────────────────────────────────────────────────────────────────────────┐
│ REQ-000008 · rest                                [In Progress] [KYC]     │
│ New onboarding · Customer · Finance                                      │
│ Pending with Shahid Hussain since 04-OCT-2026 06:04 · Score 55 (1 critical)│
└──────────────────────────────────────────────────────────────────────────┘
```
- Line 1: number · name (card-title) + status badge + key flags (KYC required, PEP, risk tier, overdue).
- Line 2: the 3–4 facts that classify the record.
- Line 3: **where it is and what happens next** (who it is waiting for, since when, due date).
- Built with the UT *Content Row* / *Hero* template or a dynamic content region using the shared CSS.

### 5.2 Field grid
- **Label above value**, never label-left with the value across the page.
- 3 / 2 / 1 columns by width (§2.3). Long text (justification, conditions) spans the full row.
- Fields grouped under short section titles (e.g. *Request · Counterparty · Assessment*).
- Empty optional fields are **hidden**; a section with nothing to show is hidden.
- Values that are links (party, case, email → mailto, phone → tel) look like links.

### 5.3 Sections and navigation
- A record with more than ~2 screens of content is split:
  - **Tabs** (UT *Tabs Container*) for peer views of one record (party: *Details · Contacts · Owners · Documents · History*).
  - **Left section navigation** for a work process with a sequence (case: *Summary → … → Review & Submit*), with a
    completion state per section (✓ done, ● current, ! needs attention).
- The header card and action bar stay visible while switching sections.

### 5.4 Related lists inside a record
Small related lists (contacts, owners, documents, history) use a **compact list** (UT *Content Row* / *Comments* /
*Timeline*), not a full-width table:
- Contacts: **Name** · job title, `Primary` badge, email and phone underneath.
- Owners/Officers: **Party name** (P-000004) · role badge · ownership % if set · *since* date.
- History and notes: **timeline**, newest first, actor name, action, time, comment.
- Edit/remove actions appear only in edit mode, as an icon menu.

### 5.5 Questionnaire answers
- Shown as **question → answer pairs** in the questionnaire's own order (no sorting, no table headers), 2 columns on
  wide screens.
- Answers that add risk or are critical carry a warning/danger badge; the total score and the number of critical
  answers are in the header card.

---

## 6. Forms

### 6.1 Labels and fields
- Label template **Above** (not floating): 13px/600 dark grey, red asterisk for required fields. No "Required" text.
- Input text 14px, field height 40px, placeholder text only as an example, never as the label.
- Help: short **inline help** under the field when it guides input; the (?) help popup only for long explanations.
- Field width follows the content: codes/dates/dropdowns in a half or third of the row, text areas full row.

### 6.2 Layout
- 2 columns for short fields, 1 column for long ones; max form width ≈ 960px.
- Fields grouped in titled sections in the order the user thinks: **who/what first, then details, then notes**.
- Choice between 2–3 paths (e.g. *Existing party / New counterparty*) uses large **selectable cards** (radio group
  with the *Pill button* / card template), each with a one-line description.

### 6.3 Validation
- Inline validation on the field, message in plain language: *"Enter the registration number."*
- On submit, errors are listed at the top as links to the fields and the first error gets focus.
- Never clear the user's input after an error.

### 6.4 Where forms open
- Create/edit of a **child record** (contact, owner, document): **drawer** (UT *Drawer* dialog, right side).
- Create/edit of a **main record**: full page or wizard.
- Confirmation and short input (reject reason, withdraw reason): **inline dialog** with the comment field in it.

### 6.5 Wizards
- UT *Wizard Progress* list, step labels 14px, current step highlighted, finished steps clickable back.
- One decision per step; the step title says what the step decides.
- Sticky footer: **Cancel** (left) · **Save as Draft** · **Previous** · **Next →** / **Submit** (right, primary).
- Last step is a **Review** of everything entered (read-only grid, *Edit* links back to the steps).

---

## 7. Actions

### 7.1 Button hierarchy
| Level | Style (UT) | Use | Max per area |
|---|---|---|---|
| Primary | Hot | The main forward action (Submit, Approve, Save) | 1 |
| Secondary | Default | Alternatives (Save as Draft, Request Information) | 2–3 |
| Tertiary | Text/link | Cancel, Back, View all | – |
| Destructive | Danger (outline) | Reject, Withdraw, Delete | 1, separated |

### 7.2 Position
- **Sticky action bar at the bottom** of record and form pages, the same on every page:
  *left: Cancel / destructive · right: secondary · primary (far right)*.
- Actions appear **once** per page (no duplicate top and bottom bars). The title bar holds only page-level create
  actions on list pages.
- Buttons show only when the user may use them (privilege + status + task); never a disabled button without a reason
  on hover.

### 7.3 Decisions (approve / reject / request information)
- Decision panel at the end of the review, or the action bar opens a **dialog**: the comment field is inside the
  dialog of the action that needs it (Reject and Request Information require a comment, Approve allows one).
- Confirmation for destructive or final actions states the effect: *"Reject REQ-000008? The requester is notified and
  can edit and resubmit."*

### 7.4 Feedback
- Success: APEX success message (auto-dismiss), past tense: *"Request REQ-000008 submitted."*
- Errors: plain language, what to do next; technical details only in debug.
- Long actions show the APEX spinner; buttons are disabled while submitting (no double submit).

---

## 8. Dashboards and worklists

- **KPI cards** (UT *Cards* or *Badge List* in card style): large number (kpi), label, icon, accent colour by meaning
  (warning for *Information Needed*, danger for *Overdue*), the **whole card is the link** to the filtered list; equal
  width in one row (3 per row on tablet, 2 on phone). No region title, no pagination.
- **My Tasks** worklist on Home: all actionable items in one list – approval tasks, case work, and **RFIs addressed to
  the user** – columns *Task (link) · Type badge · Party · Due (overdue badge) · Waiting since*, sorted by due date then
  age, *View all* to My Tasks. Empty state: *"You're all caught up."*
- No welcome or explanatory text regions.

---

## 9. Status badges

One mapping used by every list, header card and history. Rendered with the UT *Badge* / `u-` colour classes from a
single PL/SQL helper so the colours never drift.

| Object | Code → colour |
|---|---|
| Request | DRAFT neutral · IN_PROGRESS info · INFO_NEEDED warning · APPROVED success · REJECTED danger · CANCELLED neutral (label *Withdrawn*) |
| Party | PENDING warning · APPROVED success · REJECTED danger · CANCELLED neutral |
| Case | INVESTIGATION info · PENDING_APPROVAL warning · APPROVED success · REJECTED danger · CANCELLED neutral |
| Counterparty match | SELECTED success · NEW info · PENDING warning |
| Screening | NO_MATCH success · POTENTIAL_MATCH warning · CONFIRMED_MATCH danger · FALSE_POSITIVE neutral |
| Document | VERIFIED success · REJECTED danger · EXPIRED danger |
| Risk tier | LOW success · MEDIUM warning · HIGH danger |
| SLA / due | on track neutral · due ≤ 2 days warning · overdue danger |
| Task / approval step | Pending warning · Approved success · Rejected danger · Information requested warning · Submitted info |

Badges: 12px/600 text, pill shape, sentence case.

---

## 10. Content and wording

- Sentence case for titles, labels, buttons (*Create request*, not *Create Request*) – applied when a page is redone.
- Labels are nouns (*Registration number*); buttons are verbs (*Submit request*).
- No on-page paragraphs explaining the process; guidance goes into inline help or the (?) help.
- Region titles name the content, not the user (*Information requests*, not *Requests for Information Addressed to Me*).
- Same term for the same thing everywhere: *Party* (master record), *Counterparty* (the party of a request),
  *Information request* (RFI), *Case*.

---

## 11. Accessibility (WCAG 2.2 AA)

- Contrast as §2.2; focus ring visible on every interactive element (UT default, not removed).
- Every field has a real label (no placeholder-only fields); errors are linked to their field.
- All actions reachable and usable by keyboard, logical tab order, dialogs trap and return focus.
- Status is text + colour (badge text), never colour alone; icons have accessible names.
- Target size ≥ 24×24px; tables keep header cells so screen readers announce columns.

## 12. Responsive

- Breakpoints follow UT: ≥ 1200 desktop, 768–1199 tablet, < 768 phone.
- Lists: IR on desktop/tablet; on phones the key columns only (identifier, subject, status).
- Record grids collapse 3 → 2 → 1 columns; section navigation becomes a select list on phones.
- Action bar stays sticky; buttons wrap, primary stays last.

---

## 13. Implementation rules (APEX)

| Need | Use |
|---|---|
| Plain title bar | Page template option / Title Bar region without the background pattern (theme style setting, app-wide) |
| Type scale, table and form sizes | Theme Roller is **not** used (Redwood Light is fixed); one app CSS file `kyc-app.css` with the tokens of §2 scoped to UT classes |
| Labels above | Item template *Optional – Above* / *Required – Above* set as the app default |
| Badges | Shared PL/SQL `xxfnd_ui_pkg.status_badge(object, code)` returning UT badge markup; IR columns as HTML expression |
| Header card | Global Page / per-page dynamic content region using the shared CSS |
| Sticky action bar | UT *Buttons Container* region, template option *Sticky to bottom* |
| Row actions menu | UT *Actions menu* (`apex.actions` / *Menu* template) in the last IR column |
| Saved report tabs | IR saved public reports + *Show Report Tabs* (OOTB) |
| Dialog forms | Modal *Drawer* page template for child records |
| Names instead of emails | One shared helper `xxfnd_ui_pkg.person_html(user_name)` returns the employee name with a hover card (name, employee no., department, user name) from `xxfnd_employees`; used by every list, header card and history |

No inline `style=` on pages; every visual rule lives in `kyc-app.css` or UT template options.

---

## 14. Review checklist (every page before release)

- [ ] Title bar plain; breadcrumb is the way back; no *Back* button.
- [ ] First screen answers *what / state / next action* (header card or tabs).
- [ ] Data text ≥ 14px, labels 13px, nothing below 12px.
- [ ] Status, risk, overdue shown as badges; no raw codes or emails in capitals.
- [ ] Lists: ≤ 8 default columns, identifier link first, row menu last, pagination hidden on one page.
- [ ] Records: label-above-value grid, empty fields and sections hidden, sections/tabs instead of long scroll.
- [ ] Forms: labels above, asterisk for required, 2-column short fields, inline errors.
- [ ] One sticky action bar, one primary button, destructive separated and confirmed.
- [ ] Keyboard, focus and contrast checked; works at 768px and 375px width.

---

## 15. Screen backlog (recorded issues)

The standard above fixes each item; this is the per-screen list from the review.

| ID | Screen | Items |
|---|---|---|
| UX-1 | Home (1) | Remove *My Work* title and welcome region; KPI tiles → KPI cards (§8); *My Open Tasks* → *My Tasks* with type badge, party, due/overdue, *View all*; **RFIs addressed to me become rows of My Tasks** (separate region removed); plain title bar. |
| UX-2 | KYC Requests (200) | Header/data style (§4.2); saved tabs *My Requests · Pending My Action · Information Needed · All* instead of the filter chip; status/KYC badges; names instead of emails; ≤ 8 columns; row menu (View/Edit/Withdraw); Case as link; party number under the name; blank empties. |
| UX-3 | KYC Request view (205, 203 review, 206) | Header card; label-above grid in 3 groups (Request · Counterparty · Assessment); intake result split (score badge, routed to, reason); names instead of emails; *Back* button removed. |
| UX-4 | Party card (Global Page, `card_html`) | Grid not label-left; groups Identity · Relationships · Contact; name as title with number and status; relationship badges; contacts one per line; mailto; label/value weights per §2.1. |
| UX-5 | Party sub-regions | Hide empty *Additional Information*; contacts and owners/officers as compact lists (§5.4); action column only in edit mode; no pagination for one page; tabs on party/case screens. |
| UX-6 | Questionnaire answers | Q&A pairs in questionnaire order; risky/critical answers flagged; score in header card; no row count. |
| UX-7 | Create Request wizard (201, 204, 202, 203) | Labels above; 2-column short fields with max width; no "Required" text; counterparty choice first as selectable cards; sticky wizard footer; review step per §6.5. |
| UX-8 | Approval (206) and Case (211) | Single sticky action bar (no top + bottom duplicates); decision comment inside the action dialog; approval history as timeline; section navigation per §5.3. |
| UX-9 | Parties (20), Cases (210), My Tasks (40), RFIs (30), Monitoring, Dashboard, Administration | Apply §4 lists, §5 records, §6 forms, §9 badges; no screenshots needed – reviewed with before/after screenshots per chunk. |

Related defects to fix with the first chunk: **#19** Home tile links without checksum, **#20** case opened from the
Cases list raises *Task Not Found*.

## 16. Delivery plan

| Chunk | Scope | Review |
|---|---|---|
| 1 | Foundations: `kyc-app.css` tokens, plain title bar, label-above default, badge helper, sticky action bar, table style; defects #19/#20 | Before/after screenshots of Home and one list |
| 2 | Home + Requests: UX-1, UX-2, UX-3, UX-6, UX-7, UX-8 (206) | Screenshots of each page |
| 3 | Parties: UX-4, UX-5, party list/view/forms | Screenshots |
| 4 | Cases + remaining lists, monitoring, dashboard, admin (UX-8 211, UX-9) | Screenshots |

Each chunk is a patch (`apex/patches/NN-ui-…`) with tests of the pages it touches, as per the working rules.
