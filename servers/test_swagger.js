const fs = require('fs');
const path = require('path');

async function checkSwagger() {
  const urls = [
    'https://api.zendit.io/v1/swagger.json',
    'https://api.zendit.io/swagger.json',
    'https://api.zendit.io/v1/openapi.json',
    'https://api.zendit.io/openapi.json',
    'https://api.zendit.io/v1/api-docs',
  ];
  for (const u of urls) {
    try {
      const res = await fetch(u);
      console.log(u, res.status);
      if (res.ok) {
        const json = await res.json();
        console.log('Found swagger keys:', Object.keys(json));
        if (json.paths) {
          console.log('eSIM paths:', Object.keys(json.paths).filter(p => p.includes('esim')));
          if (json.paths['/esim/purchases']) {
            console.log('/esim/purchases spec:', JSON.stringify(json.paths['/esim/purchases'], null, 2));
          }
          if (json.paths['/esim/purchases/{transactionId}']) {
            console.log('/esim/purchases/{transactionId} spec:', JSON.stringify(json.paths['/esim/purchases/{transactionId}'], null, 2));
          }
          if (json.components?.schemas) {
            console.log('Schema components:', Object.keys(json.components.schemas).filter(s => s.toLowerCase().includes('esim') || s.toLowerCase().includes('purchase')));
          }
        }
      }
    } catch (e) {
      console.log(u, e.message);
    }
  }
}
checkSwagger().catch(console.error);
