import os

file_path = r"lib\features\wallet\ui\wallet_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

replacements = [
    ("'SIM SHIELD PREPAID'", "AppLocalizations.of(context)!.simShieldPrepaid"),
    ("'OFFLINE MODE'", "AppLocalizations.of(context)!.offlineMode"),
    ("'Wallet Balance'", "AppLocalizations.of(context)!.walletBalance"),
    ("'Recent Transactions'", "AppLocalizations.of(context)!.recentTransactions"),
    ("'View All'", "AppLocalizations.of(context)!.viewAll"),
    ("'Deposit Funds'", "AppLocalizations.of(context)!.depositFunds"),
    ("'Load Credit Funds'", "AppLocalizations.of(context)!.loadCreditFunds"),
    ("'Deposit Amount (USD)'", "AppLocalizations.of(context)!.depositAmountUsd"),
    ("'Please enter an amount'", "AppLocalizations.of(context)!.pleaseEnterAmount"),
    ("'Enter a positive number'", "AppLocalizations.of(context)!.enterPositiveNumber"),
    ("'Card Details'", "AppLocalizations.of(context)!.cardDetails"),
    ("'Saved Cards'", "AppLocalizations.of(context)!.savedCards"),
    ("'Visa Card Number'", "AppLocalizations.of(context)!.visaCardNumber"),
    ("'Please enter card number'", "AppLocalizations.of(context)!.pleaseEnterCardNumber"),
    ("'Must be 16 digits'", "AppLocalizations.of(context)!.mustBe16Digits"),
    ("'Expiry (MM/YY)'", "AppLocalizations.of(context)!.expiryMmYy"),
    ("'Expiry required'", "AppLocalizations.of(context)!.expiryRequired"),
    ("'Invalid'", "AppLocalizations.of(context)!.invalid"),
    ("'CVV'", "AppLocalizations.of(context)!.cvv"),
    ("'CVV required'", "AppLocalizations.of(context)!.cvvRequired"),
    ("'Verifying Card Security...'", "AppLocalizations.of(context)!.verifyingCardSecurity"),
    ("'Authorize Deposit Funds'", "AppLocalizations.of(context)!.authorizeDepositFunds"),
    ("'Failed to deposit funds. Please check card connection.'", "AppLocalizations.of(context)!.failedToDepositFunds"),
    ("'No saved payment methods found.'", "AppLocalizations.of(context)!.noSavedPaymentMethods"),
    ("'Add Payment Method'", "AppLocalizations.of(context)!.addPaymentMethod"),
    ("'Saved Payment Methods'", "AppLocalizations.of(context)!.savedPaymentMethods"),
    ("'Add another payment method'", "AppLocalizations.of(context)!.addAnotherPaymentMethod"),
    ("'No transactions yet'", "AppLocalizations.of(context)!.noTransactionsYet"),
    ("'Make a deposit or payment to see it here'", "AppLocalizations.of(context)!.makeDepositOrPayment"),
    ("'Deposit'", "AppLocalizations.of(context)!.deposit"),
    ("'Withdrawal'", "AppLocalizations.of(context)!.withdrawal"),
    ("'Payment'", "AppLocalizations.of(context)!.payment"),
    ("'Refund'", "AppLocalizations.of(context)!.refund"),
    ("'Pending'", "AppLocalizations.of(context)!.pending"),
    ("'Failed'", "AppLocalizations.of(context)!.failed"),
    ("'Completed'", "AppLocalizations.of(context)!.completed"),
]

for old, new in replacements:
    content = content.replace(old, new)

# Handle string interpolations
content = content.replace(
    "'Successfully deposited \\$${amount.toStringAsFixed(2)} USD!'",
    "AppLocalizations.of(context)!.successfullyDeposited(amount.toStringAsFixed(2))"
)
content = content.replace(
    "'Deposit via Card ending in ${method.last4}'",
    "AppLocalizations.of(context)!.depositViaCard(method.last4)"
)
content = content.replace(
    "'Expires ${method.expMonth.toString().padLeft(2, \\'0\\')}/${method.expYear.toString().substring(2)}'",
    "AppLocalizations.of(context)!.expiresMmYy(method.expMonth.toString().padLeft(2, '0'), method.expYear.toString().substring(2))"
)

# Replace line 11
import_line = "import 'package:flutter_gen/gen_l10n/app_localizations.dart';"
if import_line not in content:
    content = content.replace(
        "import 'package:flutter/material.dart';",
        "import 'package:flutter/material.dart';\n" + import_line
    )

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Replaced!")
