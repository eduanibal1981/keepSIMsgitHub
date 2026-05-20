const { chromium } = require('playwright');

(async () => {
  console.log('--- Launching Playwright to extract Supabase Token ---');
  try {
    const browser = await chromium.launch({ headless: true });
    
    // Create page and go to app
    const context = await browser.newContext();
    const page = await context.newPage();
    await page.goto('http://localhost:3000/#/home');
    await page.waitForTimeout(2000); // Wait for load and potential auth restore

    const token = await page.evaluate(() => {
      // Find any localStorage key containing auth-token
      for (let i = 0; i < localStorage.length; i++) {
        const key = localStorage.key(i);
        if (key.includes('auth-token')) {
          return { key, value: localStorage.getItem(key) };
        }
      }
      return null;
    });

    if (token) {
      console.log('TOKEN_FOUND:', JSON.stringify(token));
    } else {
      console.log('TOKEN_NOT_FOUND: LocalStorage was empty or no auth key present.');
    }

    await browser.close();
  } catch (e) {
    console.error('ERROR:', e.message);
  }
})();
