# Zenvique System — Plan (SPEC)

Last updated: 17 Nov 2026 · Status: draft for owner review

All numbers below are starting values. The owner can change them later in **Settings**. All data in the system is **sample data**. Money is shown like **RM 1,234.50**. Dates are shown like **17 Nov 2026**.

---

## A. Purpose

Zenvique has several outlets and one HQ store. This system lets us:

- record every sale at every outlet, every day
- see which outlets are doing well or poorly
- see which staff brought in sales and how much commission they earned
- see which lead sources, referrals and vouchers bring in customers
- know which products are running low, at HQ and at each outlet

---

## B. Who can see / add / edit / delete what

| | Staff | Manager | Owner |
|---|---|---|---|
| **Sales** – see | Only sales they're named in (Consultant, Service Staff or Product Seller) or typed in themselves | All sales at **their own outlet** | All sales, all outlets |
| **Sales** – add | Yes (for their outlet) | Yes (their outlet) | Yes (any outlet) |
| **Sales** – edit | Only sales they typed in | Any sale at their outlet, **but the change waits for owner approval** (this includes **status changes**: Transaction, Payment, Review) | Any sale (changes apply straight away). Approves or rejects manager changes |
| **Customers** – see | Customers they served or added | Customers of their outlet | All |
| **Customers** – add | Yes (automatically when a sale is saved) | Yes | Yes |
| **Customers** – edit (status, VIP, birthday…) | No | Yes, **waits for owner approval** | Yes |
| **Customers** – delete | No | No | Yes |
| **Stock issue status** (Damaged, Expired…) | No | Their outlet, **waits for owner approval** | Yes |
| **Alerts box** | Their own sales, commission and customers | Their outlet | All outlets |
| **Sales** – delete | No | No | Yes |
| **Commission** – see | **Only their own share** | **Only their own share** | Everyone |
| **Stock** – see | No | Their outlet only | HQ + every outlet + grand total |
| **Stock** – count / adjust | No | Their outlet only | Anywhere |
| **Stock** – move from HQ to an outlet | No | No | Yes |
| **Settings** (outlets, item list, prices, commission %, alert numbers) | Read only | Read only | Change |
| **Users** – change role, outlet, active/inactive | No | No | Yes |
| **History log** (who did what) | No | Their outlet | Everything |

Note: a manager sees **only their assigned outlet**. A manager can fix a sale, but the fix is saved as **"Pending approval"** with a reason. The sale keeps its old numbers (total, commission, stock) until the owner clicks **Approve**. If the owner clicks **Reject**, the old numbers stay and the manager is told why. This replaces the general house rule that managers see and edit everything.

---

## C. Data (what we store)

*On 17 Nov 2026 the owner approved a **3rd business table, Customers** (client database), above the usual limit of 2.*

### Statuses on every sale

| Status | Choices | Notes |
|---|---|---|
| Transaction Status | Completed / Cancelled / Refunded | Cancelled and Refunded sales earn **no commission**, give the product **back to stock**, and are left out of sales totals |
| Payment Status | Paid / Partial / Outstanding | Partial and Outstanding need a **Balance owed (RM)** and a **Due date** |
| Review Status | OK / Needs review / Pending approval | as before |
| Customer Status | New / Active / Follow-up / Inactive (+ VIP yes/no) | kept on the **customer**, not the sale |
| Stock Issue Status | OK / Damaged / Expired / Missing / Recount needed | kept on each **stock** line |

### Business table 3 — Customers (client database)

| Field | Example |
|---|---|
| Name, Phone, Email | Cindy Wong, 012-345 6789 |
| Birthday | 17 Nov 1990 |
| Home outlet | Eco Ardence |
| Customer Status, VIP | Active, Yes |
| Lead source, Referred by, Notes | Instagram, Old Client |
| Visits, Total spend, First visit, Last visit | worked out automatically from Completed sales |

Every sale is linked to a customer. When a sale is saved, the system finds the customer by **phone**, or by **name at that outlet** if there's no phone. If there's no match, it creates a new customer.

### Business table 1 — Sales (one row per transaction)

| Field | Example |
|---|---|
| Date | 17 Nov 2026 |
| Outlet | Bangsar (must be filled in) |
| Customer Name | Sample Customer 1 |
| Phone | 012-345 6789 |
| **Paid today (personal sales)** | |
| Consultant / Client Owner | Staff A |
| Treatment / package sold | Hifu 10 sessions |
| Treatment Amount | RM 3,880.00 |
| Product Seller | Staff C |
| Product | Serum 30ml |
| Product Qty | 1 |
| Product Amount | RM 120.00 |
| Discount / Promo | RM 20.00 |
| **Service done today (beautician commission)** | |
| Treatment done | Discovered trt 2/4 |
| Session Amount | RM 199.50 (package RM 798 ÷ 4 sessions). This is not money paid |
| Beautician + rate | Staff B · FULL 5% |
| 2nd Beautician + rate (if shared) | Staff D · SHARE 2% |
| **Other** | |
| Voucher Used | Yes / No |
| Voucher Type / Code | NEWYEAR10 |
| Referral Source / Referred By | Sample Customer 5 |
| Lead Source | Instagram, Walk-in, Facebook, Referral … |
| Campaign Name | Nov Glow Promo |
| Payment Method | Bank Transfer, Cash, Card, E-Wallet, SPayLater / ShopeePay, Atomy |
| Total Sale (paid today) | worked out automatically: Treatment + Product − Discount |
| Consultant, Product Seller, Beautician and 2nd Beautician Commission | worked out automatically (see section E) |
| Status | OK / Needs review / Pending approval |
| Proposed Change | the manager's fix, waiting for owner approval (old values stay in use until approved) |
| Change Reason | why the manager changed it, e.g. "wrong amount keyed in" |
| Notes | free text |
| (automatic) ID, created at, created by | |

Consultant, Beautician(s) and Product Seller are kept **separately** because they can be different people. Lead Source and Voucher are also kept **separately**. A row can be a payment, a service done, or both. A package session with no payment is a row with RM 0.00 paid and a Service line.

### Business table 2 — Stock (one row per product per location)

| Field | Example |
|---|---|
| Location | HQ, Bangsar, Puchong … |
| Product | Serum 30ml |
| Quantity | 25 |
| Reorder Level | 5 |
| (automatic) ID, created at, created by | |

### Supporting tables

- **Profiles**: each user's name, email, role (Owner / Manager / Staff), **assigned outlet**, and active yes/no.
- **Settings**: the outlet list, the item list (treatments, products and services, each with a price), the commission % values, and the alert numbers in section E.
- **History log**: who did what and when. This covers every new sale, status change, stock change, stock move and role change.
- **AI briefs**: saved monthly briefs (see section G).

---

## D. Screens per role

| Screen | Staff | Manager | Owner |
|---|---|---|---|
| Login | ✓ | ✓ | ✓ |
| **New Sale**: outlet, customer, *Paid today* (treatment, product, consultant, seller, discount, payment) and/or *Service done today* (treatment done, session amount, beautician(s) and rate), voucher, referral, lead source | ✓ | ✓ | ✓ |
| **My Sales & Commission**: pick a month. My commission per outlet (Treatment 1% × RM, Product 5% × RM, Service Comm Total) and a grand total, like the monthly commission sheet; my treatment service record (date, customer, treatment, amount, FOC / FULL / SHARE column, Com Amt) like the beauticians' sheet; my sales list with status; download my sheet as CSV. Only my own commission is ever shown | ✓ | ✓ | ✓ |
| **Manager Dashboard** (own outlet only): Branch Total Sales, Sales Target Achievement % (target, actual, remaining), My Personal Sales (sales where I am the Consultant, still counted in the branch total), Sales Volume, Treatment Sales; then Product Sales, Service Done, New Customers, Low Stock, 6-month trend, treatment / product breakdown, lead source, referral source, voucher usage, stock inventory, alerts. No other staff's commission, no other outlets. Also: **Sales records** (update Transaction / Payment / Review status), **Stock** (update Stock Issue), **Customers** (status, VIP, birthday, notes). Rows are coloured Red / Amber with a legend; a manager's updates are sent to the owner for approval, and every number on the page refreshes as soon as a change is saved | | ✓ | ✓ (pick any outlet) |
| **Review List**: sales marked "Needs review" or "Pending approval". Manager fixes the sale; owner sees old vs new side by side and clicks Approve or Reject | | ✓ (fix) | ✓ (approve / reject) |
| **Stock**: outlet stock, low-stock list, enter a stock count | | ✓ | ✓ |
| **Owner Dashboard**: pick Month / Quarter / Year. All outlets total sales, target vs actual, sales volume, treatment / product / service, total commission, new customers, low stock; outlet comparison (sales, target, achieved %, volume…; click an outlet to open its Manager view); monthly / quarterly / yearly trend; staff performance; stock across all locations; lead source, referral, voucher | | | ✓ |
| **HQ Stock & Transfers**: HQ stock, move stock from HQ to an outlet, grand total | | | ✓ |
| **Owner tabs**: Overview · Users · Settings · History · Download · Manager view | | | ✓ |
| **Users** tab: add user (send the sign-up link by copy or WhatsApp), change role, assign outlet, switch on/off. The owner can't switch themselves off | | | ✓ |
| **Settings** tab: monthly sales target per outlet, commission % and beautician rates, treatment / service / product lists with prices, reorder levels, lead sources, voucher types, review rules | | | ✓ |
| **History** tab: who changed what and when, with before → after values | | | ✓ |
| **Download** tab: sales, commission records, commission summary (per person per outlet), inventory, customers, lead sources, voucher usage as CSV (opens in Excel) | | | ✓ |
| **Alerts box** (on every dashboard) | ✓ | ✓ | ✓ |

Every screen works on a phone.

---

## E. Rules (with exact numbers)

| Rule | Starting value |
|---|---|
| Consultant commission (personal sales) | **1%** of the Treatment Amount, after its share of the discount |
| Product Seller commission | **5%** of the Product Amount, after its share of the discount |
| Beautician (service) commission | Session Amount × the rate picked: **FULL 5%**, **FOC 1% / 2% / 3%**, or **SHARE 1% / 2% / 3% / 4%** |
| 2nd Beautician (shared treatment) | Session Amount × their own rate (usually a SHARE %) |
| Discount sharing | the discount is shared between Treatment and Product by size (e.g. RM 200 + RM 100 with RM 30 off → RM 180 + RM 90) |
| Rounding | commission is rounded **down** to the sen (RM 199.50 × 5% = RM 9.97) |
| Monthly commission view | per person, per outlet: Treatment 1% + Product 5% + Service total, as in the current commission sheet |
| Commission is worked out automatically when a sale is saved, and again if the sale is edited | — |
| Selling a product lowers **that outlet's** stock by the Product Qty | — |
| **Low Stock** | when quantity is **equal to or below** the reorder level |
| Moving stock from HQ to an outlet | lowers HQ stock and raises outlet stock by the same amount |
| Every sale must belong to an outlet | the sale can't be saved without one |
| Manager's change to a sale | totals, commission and stock change **only after** the owner approves |
| Monthly sales target | set by the owner per outlet per month (Settings); managers can only see it. Achievement % = branch sales ÷ target |
| New customer | a customer (matched by phone, or by name if no phone) whose **first visit to that outlet** is in the chosen month |
| Sales Volume | number of transactions with money paid (package sessions with RM 0.00 paid are counted as Service Done instead) |

| Commission rates used | the % in force when a sale is saved is stored on the sale, so later rule changes don't rewrite old commission (an edit uses the rates of the day) |

### Row colours and alerts (all numbers in Settings → Colour rules)

**Red = Act now**

| Rule | Starting value |
|---|---|
| Critical low stock | quantity is 0, or at/below **50%** of the reorder level |
| Overdue outstanding payment | balance still owed **0 days** after the due date |
| Invalid / incomplete sale | an amount with no item named, or Partial/Outstanding without balance or due date |
| Missing staff | Treatment without Consultant, Service without Beautician, or Product without Product Seller |
| Commission calculation error | saved commission doesn't match the rates saved on the sale |

**Amber = Watch**

| Rule | Starting value |
|---|---|
| Low stock | at or below the reorder level |
| Behind sales target | branch sales are below **80%** of where they should be by today (target × day ÷ days in month) |
| Partial / outstanding payment | not yet overdue |
| Needs review / Pending approval | any such sale |
| Missing marketing details | paid sale with no lead source; "Referral" with no name; voucher used with no type/code |
| Unusually high discount | discount above **20%** of the paid amount |
| Your sale was changed (staff) | someone else edited a sale with your name in the last **7 days** |

Alerts look back over the last **90 days** of sales.

A sale is marked **"Needs review"** when any of these happen:

| Flag | Starting value |
|---|---|
| Big discount | discount is **more than 30%** of (Treatment + Product) |
| Large sale | Total Sale is **above RM 5,000.00** |
| Missing details | money paid but no Phone, **or** no Consultant, **or** no Lead Source; **or** a service done with no Beautician |
| Stock doesn't tally | the sale would take stock **below 0** |

Other warnings (go to the Alerts box, not to a single sale):

| Warning | Starting value |
|---|---|
| Quiet outlet | an outlet has **0 sales** on a day it is open (Mon–Sun) |
| Stock doesn't tally | a manager's stock count is **different** from what the system expects |

*Note: we read "stock inventory not tele" as "stock doesn't tally". Please correct us if you meant something else.*

---

## F. KPIs (5), each with an action

| # | KPI | What it shows | Action when it looks bad |
|---|---|---|---|
| 1 | **Monthly Sales** | Total RM this month, per outlet and overall, vs last month | If an outlet is more than 20% down on last month → manager checks staff performance and lead sources |
| 2 | **Number of Transactions** | How many sales this month | If it's low but Monthly Sales is OK → fewer customers are spending more; push campaigns to bring in new customers |
| 3 | **Treatment Sales** | RM from treatments this month | If it's dropping → check the consultants' follow-ups and treatment promos |
| 4 | **Product Sales** | RM from products this month | If it's dropping → remind sellers to recommend products after each treatment |
| 5 | **Low Stock Items** | Number of products at or below their reorder level | Manager asks the owner for a stock move from HQ; owner reorders when HQ is low |

**Owner also sees (secondary):** commission per staff member, and sales broken down by lead source, voucher and referral.

---

## G. AI feature

**Monthly Brief button** (manager and owner dashboards):

1. The app writes a ready-made question for Claude using the numbers shown on screen, such as sales per outlet, top staff, top lead sources and low stock.
2. You copy it into Claude, read the answer, and fix anything wrong.
3. You tick **"I have checked this"** and click **Save**. The brief is kept in the AI briefs list.

**Never-do list:**

- Never put an AI key inside the app.
- Never send anything to customers automatically.
- Never let AI change sales, stock or commission.
- Never put customer phone numbers in the AI question.
- Never save a brief without the "I have checked this" tick.

---

## H. Not today (maybe later)

- More than one product in a single sale
- Purchase orders to suppliers
- Payroll and payslips
- Online payments
- Customers booking by themselves
- Any message sent automatically
- Customer loyalty points

---

## I. Notifications (who, when, how)

| Who | When | How |
|---|---|---|
| Staff | Their commission on a sale is changed or adjusted | Alerts box |
| Manager | A product at their outlet reaches Low Stock | Alerts box + WhatsApp button (pre-typed message to the owner) |
| Manager | A sale at their outlet is marked "Needs review" | Alerts box |
| Owner | Low Stock at HQ or any outlet | Alerts box |
| Manager | The owner approves or rejects their change | Alerts box |
| Owner | A manager changes a sale (waiting for approval) | Alerts box + WhatsApp button (pre-typed message from the manager) |
| Owner | Sales marked "Needs review", quiet outlets, stock counts that don't tally | Alerts box |
| Owner | Monthly summary (optional): outlet sales, commission, lead sources | "Monthly summary" button that opens a pre-typed WhatsApp message |

**Alerts box at the top of every user's page**, Red first and then Amber, with a small legend:
- **Staff:** only alerts about their own sales, commission and customers
- **Manager:** only alerts for their assigned outlet
- **Owner:** alerts across all outlets, including every change waiting for approval

When an alert needs follow-up with a customer (e.g. overdue payment) or with a staff member (e.g. missing details), it shows a **Send WhatsApp** button with the message already typed. Staff phone numbers come from their profile.

WhatsApp buttons only **open** a pre-typed message. A person always checks it and presses Send. Nothing is ever sent to customers automatically. Every status change, approval, rejection and manual adjustment is written to the History log.
