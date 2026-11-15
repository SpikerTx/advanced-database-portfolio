// =====================================================================
// MIT 8103 | Portfolio 4 | MongoDB document model for Access Pensions Limited (synthetic data)
// Runs automatically in the official mongo image (docker-entrypoint-initdb.d) or manually:
//   mongosh --file portfolio-4-nosql/mongodb/init/01_seed_access_pensions.js
// Collections
//   customers            one document per RSA holder (biodata + embedded next of kin + last 5 transactions)
//   benefitApplications  polymorphic documents: `details` differs by benefit type
// =====================================================================
const adb = db.getSiblingDB('access_pensions');
const N_CUSTOMERS = 5000;

// ---- deterministic pseudo-random generator (mulberry32) so every run produces the same data ----
let _s = 2026;
function rnd() {
  _s |= 0; _s = (_s + 0x6D2B79F5) | 0;
  let t = Math.imul(_s ^ (_s >>> 15), 1 | _s);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const pick = (a) => a[Math.floor(rnd() * a.length)];
const money = (n) => NumberDecimal(n.toFixed(2));
const daysAgo = (d) => new Date(Date.now() - d * 86400000);

const SURNAMES = ['Okafor','Adeyemi','Bello','Eze','Ibrahim','Okonkwo','Balogun','Udoh','Nwosu','Abubakar','Adebayo','Chukwu','Musa','Ogunleye','Danjuma'];
const MALE = ['Chinedu','Tunde','Musa','Emeka','Ibrahim','Segun','Kelechi','Yusuf'];
const FEMALE = ['Ngozi','Amina','Funke','Chiamaka','Zainab','Bukola','Ifeoma','Hauwa'];
const FUNDS = [{code:'RSA_I',name:'RSA Fund I'},{code:'RSA_II',name:'RSA Fund II'},{code:'RSA_III',name:'RSA Fund III'},{code:'MPF',name:'Micro Pension Fund'}];
const RETIREE_FUND = {code:'RSA_IV',name:'RSA Fund IV'};
const EMPLOYERS = [
  {name:'Atlas Freight Nigeria Ltd',sector:'Logistics'},{name:'Bluewater Offshore Services Ltd',sector:'Oil & Gas'},
  {name:'Delta Grain Mills Ltd',sector:'Agro-processing'},{name:'Federal Works Directorate (Simulated)',sector:'Public Sector'},
  {name:'Greenfield Pharma Nigeria Ltd',sector:'Healthcare'},{name:'Kano Textile Works Ltd',sector:'Manufacturing'},
  {name:'Oriental Telecom Nigeria Ltd',sector:'Telecoms'},{name:'Quest Software Systems Ltd',sector:'Technology'},
  {name:'Savanna Cement Company Ltd',sector:'Manufacturing'},{name:'Vista Retail Stores Ltd',sector:'Retail'}];
const BANKS = ['Access Bank','Zenith Bank','Guaranty Trust Bank','First Bank of Nigeria','United Bank for Africa','Fidelity Bank'];

// ---- (re)create collections with JSON Schema validation ----
adb.customers.drop();
adb.benefitApplications.drop();

adb.createCollection('customers', {
  validator: { $jsonSchema: {
    bsonType: 'object',
    required: ['_id', 'name', 'contact', 'fund', 'employer', 'bank', 'denomination', 'status', 'currentBalance', 'nextOfKin'],
    properties: {
      _id:    { bsonType: 'string', pattern: '^PEN[0-9]{12}$', description: 'Pension PIN' },
      name:   { bsonType: 'object', required: ['surname', 'firstName'],
                properties: { surname: { bsonType: 'string' }, firstName: { bsonType: 'string' },
                              otherNames: { bsonType: ['string', 'null'] } } },
      contact:{ bsonType: 'object', required: ['phone'],
                properties: { phone: { bsonType: 'string', pattern: '^0[0-9]{10}$' }, email: { bsonType: ['string', 'null'] } } },
      status: { enum: ['ACTIVE', 'RETIRED', 'DECEASED'] },
      denomination: { bsonType: 'string', pattern: '^[A-Z]{3}$' },
      currentBalance: { bsonType: 'decimal' },
      nextOfKin: { bsonType: 'array', minItems: 1 }
    } } },
  validationLevel: 'strict', validationAction: 'error'
});

adb.createCollection('benefitApplications', {
  validator: { $jsonSchema: {
    bsonType: 'object',
    required: ['customerPin', 'type', 'status', 'applicationDate', 'amountRequested', 'details'],
    properties: {
      type:   { enum: ['25_PERCENT_WITHDRAWAL', 'EQUITY_MORTGAGE_WITHDRAWAL', 'LUMP_SUM_WITHDRAWAL', 'VOLUNTARY_WITHDRAWAL', 'DEATH_BENEFIT_WITHDRAWAL'] },
      status: { enum: ['PENDING', 'APPROVED', 'REJECTED', 'PAID'] },
      amountRequested: { bsonType: 'decimal' },
      details: { bsonType: 'object' }
    } } }
});

// ---- generate documents ----
const customers = [];
const applications = [];

for (let i = 1; i <= N_CUSTOMERS; i++) {
  const r = rnd();
  const status = r < 0.03 ? 'DECEASED' : r < 0.15 ? 'RETIRED' : 'ACTIVE';
  const male = rnd() < 0.5;
  const first = pick(male ? MALE : FEMALE);
  const surname = pick(SURNAMES);
  const employer = pick(EMPLOYERS);
  const balance = 50000 + rnd() * 9000000;
  const pin = 'PEN' + String(100000000000 + i);

  // last five transactions (subset pattern: older history stays in the relational ledger / a separate collection)
  const recent = [];
  let running = balance;
  const monthly = 18000 + rnd() * 162000;
  for (let k = 0; k < 5; k++) {
    recent.push({ date: daysAgo(30 * k + 2), type: 'CONTRIBUTION', source: k % 2 ? 'EMPLOYER' : 'EMPLOYEE',
                  amount: money(monthly * (k % 2 ? 10 / 18 : 8 / 18)), balanceAfter: money(running) });
    running = Math.max(running - monthly, 0);
  }

  const nok = [{ fullName: pick(['Adaeze', 'Tolu', 'Hassan', 'Ngozi']) + ' ' + surname, relationship: pick(['Spouse', 'Child', 'Sibling']),
                 phone: '0803' + String(1000000 + i).slice(-7), sharePercent: 100 }];

  customers.push({
    _id: pin,
    name: { surname, firstName: first, otherNames: rnd() < 0.6 ? pick(['Oluwaseun', 'Chukwuemeka', 'Ifeanyi']) : null },
    gender: male ? 'M' : 'F',
    dateOfBirth: daysAgo(365 * (status === 'ACTIVE' ? 25 + rnd() * 30 : 60 + rnd() * 15)),
    contact: { phone: '0' + pick(['803', '806', '810', '813', '816']) + String(1000000 + ((i * 7919) % 9000000)),
               email: rnd() > 0.08 ? (first + '.' + surname + i + '@example.com').toLowerCase() : null },
    accountCreatedOn: daysAgo(60 + rnd() * 720),
    fund: status === 'ACTIVE' ? pick(FUNDS) : RETIREE_FUND,
    employer: employer,
    bank: { name: pick(BANKS), accountNo: String(1000000000 + ((i * 7919) % 9000000000)).slice(0, 10) },
    denomination: 'NGN',
    status: status,
    currentBalance: money(balance),
    nextOfKin: nok,
    recentTransactions: recent
  });

  // ~15% of customers have one benefit application; `details` differs by type (polymorphism)
  const a = rnd();
  let type = null;
  if (status === 'ACTIVE')        type = a < 0.04 ? '25_PERCENT_WITHDRAWAL' : a < 0.07 ? 'EQUITY_MORTGAGE_WITHDRAWAL' : a < 0.09 ? 'VOLUNTARY_WITHDRAWAL' : null;
  else if (status === 'RETIRED')  type = a < 0.6 ? 'LUMP_SUM_WITHDRAWAL' : null;
  else                            type = a < 0.8 ? 'DEATH_BENEFIT_WITHDRAWAL' : null;
  if (type) {
    const cap = (type === '25_PERCENT_WITHDRAWAL' || type === 'EQUITY_MORTGAGE_WITHDRAWAL') ? balance * 0.25 : balance;
    const st = pick(['PENDING', 'PENDING', 'APPROVED', 'PAID', 'PAID', 'PAID', 'REJECTED']);
    const details =
      type === '25_PERCENT_WITHDRAWAL'         ? { reason: 'Unemployment', monthsUnemployed: 4 + Math.floor(rnd() * 8) } :
      type === 'EQUITY_MORTGAGE_WITHDRAWAL'    ? { lender: pick(['Federal Mortgage Bank', 'Sterling Mortgage', 'Haven Housing Finance']),
                                                   propertyState: pick(['Lagos', 'Abuja FCT', 'Rivers', 'Oyo']), offerLetterRef: 'OFR-' + i } :
      type === 'LUMP_SUM_WITHDRAWAL'           ? { retirementOption: pick(['Programmed Withdrawal', 'Annuity']), retirementDate: daysAgo(60) } :
      type === 'VOLUNTARY_WITHDRAWAL'          ? { purpose: pick(['Education', 'Medical', 'Business']) } :
                                                 { deathCertificateNo: 'DC-' + i, claimants: nok.map((n) => ({ name: n.fullName, share: n.sharePercent })) };
    applications.push({
      customerPin: pin, type: type, status: st, applicationDate: daysAgo(rnd() * 90),
      amountRequested: money(cap * (0.5 + rnd() * 0.5)), details: details,
      history: [{ status: 'PENDING', at: daysAgo(90), by: 'portal' }].concat(st === 'PENDING' ? [] : [{ status: st, at: daysAgo(10), by: 'seed.officer' }])
    });
  }
}

// ---- bulk insert in batches ----
for (let i = 0; i < customers.length; i += 1000) adb.customers.insertMany(customers.slice(i, i + 1000));
for (let i = 0; i < applications.length; i += 1000) adb.benefitApplications.insertMany(applications.slice(i, i + 1000));

// ---- indexes chosen from the access patterns in queries.js ----
adb.customers.createIndex({ 'contact.phone': 1 });
adb.customers.createIndex({ 'name.surname': 1, 'name.firstName': 1 });
adb.customers.createIndex({ 'employer.name': 1, status: 1 });
adb.benefitApplications.createIndex({ customerPin: 1, applicationDate: -1 });
adb.benefitApplications.createIndex({ status: 1, type: 1 });
adb.benefitApplications.createIndex({ applicationDate: 1 }, { partialFilterExpression: { status: 'PENDING' } });

print('MongoDB seed complete: customers=' + adb.customers.countDocuments() +
      ' benefitApplications=' + adb.benefitApplications.countDocuments());
