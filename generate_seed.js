const fs = require('fs');

const data = JSON.parse(fs.readFileSync('./testsprite_tests/testsprite_frontend_test_plan.json', 'utf8'));

let sql = `INSERT INTO public.test_cases (feature_group, test_name, status) VALUES\n`;

const values = data.map(tc => {
    const category = tc.category.replace(/'/g, "''");
    const title = tc.title.replace(/'/g, "''");
    return `('${category}', '${title}', 'pending')`;
});

sql += values.join(',\n') + ';';

fs.writeFileSync('seed_test_cases.sql', sql);
console.log('Done writing seed_test_cases.sql');
