# Normalisation explanation (Portfolio 1)

**Starting point (un-normalised customer record):** one wide row containing surname, first name, other names, account-creation date, fund type, phone, email, PIN, employer name, bank name, bank account number, denomination, plus repeated groups of transactions and benefit applications.

| Normal form | Problem in the raw record | Resolution in the schema |
|---|---|---|
| **1NF** – atomic values, no repeating groups | Transactions, benefit applications and next-of-kin repeat per customer | Moved to `account_transaction`, `benefit_application`, `next_of_kin`; name split into surname / first_name / other_names |
| **2NF** – no partial dependency on part of a key | In a transaction row keyed by (customer, date, employer) the employer name depends on employer only | Employer attributes live in `employer`; transactions store `employer_id` |
| **3NF** – no transitive dependency | `fund_name`/`risk_profile` depend on fund type, `bank_name` depends on bank, not on the customer | Extracted `fund_type`, `bank`, `employer` lookup tables referenced by foreign keys |
| **BCNF** | Candidate keys: `customer_id`, `pension_pin`, (`bank_id`,`bank_account_no`) – every determinant is a candidate key | Each is declared PRIMARY KEY or UNIQUE |

## Deliberate, controlled denormalisation
* `customer.current_balance` and `account_transaction.balance_after` are **derived** values (the sum of the ledger). They are kept because (a) the case-study specification requires a Balance on each transaction, and (b) it makes balance enquiries O(1) and gives a natural row to lock for concurrency control (Portfolio 3).
* Integrity is protected: only trigger `fn_post_transaction()` writes them; the ledger is append-only (trigger `fn_ledger_immutable`); `scripts/verify_build.sql` recomputes every running balance and must report 0 violations.

## Keys and constraints summary
* Surrogate primary keys (`GENERATED ALWAYS AS IDENTITY`) on all tables; natural keys (`pension_pin`, `fund_code`, `employer_name`, `bank_name`, `reference`) protected by UNIQUE.
* Foreign keys on every relationship; `next_of_kin` cascades on customer delete, all others restrict.
* CHECK constraints: PIN format `PEN` + 12 digits, Nigerian phone format, e-mail shape, 10-digit account number, ISO currency code, non-negative balances, positive amounts, and a row-shape rule that forces contributions to carry a source/employer and payments to reference an approved benefit.
