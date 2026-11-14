# Progressive commit guide

The brief rewards **progressive** commits. Commit each piece **when you have actually worked on it, run it and understood it** – do not back-date commits or upload everything at once. Suggested sequence:

1. `chore: add repository structure and README`
2. `feat(p1): add case-study description and ER diagram`
3. `feat(p1): create relational schema and constraints`
4. `feat(p1): add ledger trigger, benefit workflow functions`
5. `feat(p1): add synthetic data generator and verification checks`
6. `feat(p2): add benchmark queries and baseline execution plans`
7. `feat(p2): add indexes and materialised view; record after-plans`
8. `feat(p3): add commit/rollback demonstrations`
9. `feat(p3): add isolation, locking, deadlock and serializable demos`
10. `feat(p4): add MongoDB model and queries`
11. `feat(p4): add PostgreSQL JSONB documents`
12. `feat(p5): add replication stack and verification`
13. `feat(p5): add partitioning/sharding and cloud design`
14. `docs: add screenshots, reflection and AI-use declaration`

```bash
git init -b main && git add . && git commit -m "chore: add repository structure and README"
git remote add origin https://github.com/<your-username>/advanced-database-portfolio.git
git push -u origin main
```
Make the repository **private** and add the assessor/lecturer as a collaborator before submitting (check the LMS for the account to invite).
