// MIT 8103 | Portfolio 4 | Representative MongoDB operations. Run:
//   mongosh access_pensions --file portfolio-4-nosql/mongodb/queries.js
const adb = db.getSiblingDB('access_pensions');
const show = (title, x) => { print('\n=== ' + title + ' ==='); printjson(x); };

// 1. Primary-key lookup (_id = Pension PIN): one read returns the whole customer profile
show('1. Customer by PIN', adb.customers.findOne({ _id: 'PEN100000000001' }));

// 2. Phone lookup, with the execution plan proving index use
show('2. Phone lookup (explain)', adb.customers.find({ 'contact.phone': adb.customers.findOne({}, { 'contact.phone': 1 }).contact.phone })
      .explain('executionStats').executionStats);

// 3. Aggregation: total and average balance per fund
show('3. Balance by fund', adb.customers.aggregate([
  { $match: { status: { $ne: 'DECEASED' } } },
  { $group: { _id: '$fund.name', customers: { $sum: 1 }, totalBalance: { $sum: '$currentBalance' }, avgBalance: { $avg: '$currentBalance' } } },
  { $sort: { totalBalance: -1 } }]).toArray());

// 4. Aggregation: top employers by number of active customers
show('4. Top employers', adb.customers.aggregate([
  { $match: { status: 'ACTIVE' } },
  { $group: { _id: '$employer.name', activeCustomers: { $sum: 1 } } },
  { $sort: { activeCustomers: -1 } }, { $limit: 5 }]).toArray());

// 5. Polymorphic query: equity-mortgage applications by lender (field exists only for that benefit type)
show('5. Pending equity-mortgage applications by lender', adb.benefitApplications.aggregate([
  { $match: { type: 'EQUITY_MORTGAGE_WITHDRAWAL', status: 'PENDING' } },
  { $group: { _id: '$details.lender', applications: { $sum: 1 }, requested: { $sum: '$amountRequested' } } },
  { $sort: { applications: -1 } }]).toArray());

// 6. $lookup (join) pending applications with customer name and employer
show('6. Pending applications with customer', adb.benefitApplications.aggregate([
  { $match: { status: 'PENDING' } }, { $sort: { applicationDate: 1 } }, { $limit: 3 },
  { $lookup: { from: 'customers', localField: 'customerPin', foreignField: '_id', as: 'customer' } },
  { $unwind: '$customer' },
  { $project: { type: 1, amountRequested: 1, 'customer.name': 1, 'customer.employer.name': 1 } }]).toArray());

// 7. Single-document atomic update: post a contribution, keep only the 5 newest embedded transactions
show('7. Atomic contribution posting', adb.customers.findOneAndUpdate(
  { _id: 'PEN100000000002', status: 'ACTIVE' },
  { $inc: { currentBalance: NumberDecimal('50000.00') },
    $push: { recentTransactions: { $each: [{ date: new Date(), type: 'CONTRIBUTION', source: 'VOLUNTARY',
                                              amount: NumberDecimal('50000.00'), balanceAfter: NumberDecimal('0.00') }],
                                   $position: 0, $slice: 5 } } },
  { returnDocument: 'after', projection: { currentBalance: 1, recentTransactions: { $slice: 2 } } }));

// 8. Schema validation in action: this insert must be REJECTED (invalid PIN format, missing required fields)
try { adb.customers.insertOne({ _id: 'BAD-PIN', status: 'ACTIVE' }); print('UNEXPECTED: insert accepted'); }
catch (e) { print('\n=== 8. Validation rejected the document as expected: ' + e.codeName + ' ==='); }
