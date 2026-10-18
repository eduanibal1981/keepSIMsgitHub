// Existing suites deliberately group assertions into DO blocks. Isolate each
// block so one known failure does not hide unrelated failures later in the file.
export function casesFromSQL(source,label){
 const matches=[...source.matchAll(/^DO (\$[a-zA-Z0-9_]*\$)[\s\S]*?^\1;/gm)];
 if(!matches.length)throw Error('No executable financial DO cases found in '+label);
 return matches.map((match,index)=>{
   const prefix=source.slice(0,match.index).trimEnd();const name=prefix.match(/-- CASE: ([^\n]+)$/)?.[1];
   return {name:name||`${label} block ${index+1}`,sql:match[0]};
 });
}
export async function runSQLCases(db,source,label){
 const results=[];await db.exec('BEGIN');
 try{
   // The wallet suite's only shared state is its temporary result collector.
   if(source.includes('CREATE TEMP TABLE wallet_test_results'))await db.exec('CREATE TEMP TABLE wallet_test_results(test_name text,outcome text) ON COMMIT DROP');
   for(const test of casesFromSQL(source,label)){
     await db.exec('SAVEPOINT financial_case');
     try{await db.exec(test.sql);results.push({name:test.name,status:'passed'});console.log('PASS '+test.name);}
     catch(error){
       await db.exec('ROLLBACK TO SAVEPOINT financial_case');
       const result={name:test.name,status:'failed',code:error.code||null,constraint:error.constraint||null,message:error.message};
       results.push(result);console.error(`FAIL ${test.name}: ${error.message} [${error.code||'unknown'}${error.constraint?', '+error.constraint:''}]`);
     }
     // Successful cases also roll back: their synthetic countries, fee rules,
     // JWT settings and role changes must not influence another case.
     await db.exec('ROLLBACK TO SAVEPOINT financial_case');
     await db.exec('RELEASE SAVEPOINT financial_case');
   }
 }finally{await db.exec('ROLLBACK');}
 return results;
}
