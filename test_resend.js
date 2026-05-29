// Local Resend API test script
// To run this: 
// 1. Open your terminal in the keep_sims folder
// 2. Install the package: npm install resend
// 3. Run the script: node test_resend.js

import { Resend } from 'resend';

// REPLACE 're_xxxxxxxxx' with your real API Key: 're_j8b8gkxz_3ir5ZhUU6hMnzN9jxWBSRwBr'
const resend = new Resend('re_j8b8gkxz_3ir5ZhUU6hMnzN9jxWBSRwBr');

console.log('Initiating Resend transaction email test...');

resend.emails.send({
  // NOTE: On free Resend accounts, you must send FROM 'onboarding@resend.dev'
  from: 'onboarding@resend.dev',
  // NOTE: On free accounts, you can only send TO your registered email: 'abdallajava@gmail.com'
  to: 'abdallajava@gmail.com',
  subject: 'SIM Shield — Resend Integration Active',
  html: `
    <div style="font-family: sans-serif; padding: 24px; background-color: #0d0e12; color: #ffffff; border-radius: 12px; max-width: 500px;">
      <h2 style="color: #4ade80; margin-top: 0;">Resend Connected!</h2>
      <p style="color: #a9abb3; font-size: 15px; line-height: 1.6;">
        Congrats! Your local Node.js script successfully connected to the Resend API and triggered this transaction.
      </p>
      <hr style="border: 0; border-top: 1px solid #1f222e; margin: 20px 0;" />
      <p style="font-size: 12px; color: #6b7280;">SIM Shield Notification Engine</p>
    </div>
  `
}).then(response => {
  console.log('SUCCESS! Email sent successfully.');
  console.log('Response details:', response);
}).catch(error => {
  console.error('ERROR! Failed to send email.');
  console.error(error);
});
