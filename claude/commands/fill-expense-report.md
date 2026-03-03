---
name: fill-expense-report
description: Fill a Travel Expense Reimbursement Excel form from receipt files (images, PDFs). Reads receipts, extracts amounts/dates/descriptions, and populates the spreadsheet.
---

# Fill Expense Report Skill

Automatically fill a Travel Expense Reimbursement Excel form from receipt files (PDFs, images). Extracts key data from each receipt and populates the correct rows in the spreadsheet.

## Usage

```
/fill-expense-report
```

Run this from a directory containing:
1. A Travel Expense Reimbursements form (`.xlsx`)
2. One or more receipt files (`.pdf`, `.jpeg`, `.jpg`, `.png`)

You can also provide arguments to specify files:
```
/fill-expense-report path/to/form.xlsx
```

## Instructions for Claude

### Step 1: Discover Files

Use Glob to find all files in the current working directory:
- Look for `.xlsx` files (the expense form)
- Look for receipt files: `.pdf`, `.jpeg`, `.jpg`, `.png`

If multiple `.xlsx` files exist, ask the user which one is the expense form.
If no receipts are found, inform the user.

### Step 2: Read the Expense Form

Use Python with `openpyxl` to read the Excel form structure:
- Identify the currency options (typically in B6:B10) and their exact string values (including trailing spaces)
- Identify existing expense rows (rows 16-28) and find the first empty row
- Identify the Entertainment section (rows 34-38) if needed
- Note which columns map to which categories: F=Flight, G=Hotels, H=Transp., I=Car rental, J=Misc.

### Step 3: Read Each Receipt

For each receipt file:

**PDF files:** Use the Read tool to read the PDF content. Extract:
- Date of purchase/service
- Invoice/order number
- Description of what was purchased
- Total amount paid
- Currency

**Image files (JPEG/PNG):** Use the Read tool to view the image. If the image is hard to read:
- Use Python PIL/Pillow to crop relevant sections (totals area, payment terminal receipts)
- Re-read cropped sections for clarity

**CRITICAL: Final billed amount vs receipt subtotal**
- Always look for the FINAL amount charged (e.g., on card payment terminal receipts / epay slips)
- This may differ from the itemized subtotal if tip was added
- Card terminal receipts often show: subtotal, tip, and total charged
- Use the total charged amount, not the subtotal
- If you cannot clearly read the final amount, ask the user to confirm

### Step 4: Classify Each Expense

Determine the category based on the vendor/service. Use common sense:

- **Flight** (column F): Airlines, boarding passes, flight bookings (e.g., El Al, United, Ryanair, booking confirmations with flight numbers)
- **Hotels** (column G): Hotels, hostels, Airbnb, Booking.com, accommodation of any kind
- **Transportation** (column H): Any ground transport - Uber, Lyft, Bolt, Gett, taxis, trains, metro/subway, buses, ferries, toll roads, parking, airport shuttles, Lime/Bird scooters
- **Car rental** (column I): Hertz, Avis, Budget, Sixt, or any car/vehicle rental service
- **Misc.** (column J): Only things that don't fit above - eSIMs, phone plans, SIM cards, office supplies, conference fees, visa fees, travel insurance, luggage fees

**Important:** Do NOT put transportation expenses in Misc. If someone took an Uber, that's Transportation (column H), not Misc.

If a receipt looks like business entertainment (dinner with clients/partners), ask the user whether to place it in Misc. or the Entertainment section.

### Step 5: Fill the Form

Use Python with `openpyxl` to fill in the form:

1. **Back up the original file first** (copy to `.xlsx.bak`)
2. For each receipt, fill a row in the expenses section:
   - **Column B**: Invoice Date (use `datetime` object with `DD/MM/YYYY` format)
   - **Column C**: Number of days/nights (if applicable)
   - **Column D**: Invoice/receipt number
   - **Column E**: Description of expense
   - **Column F-J**: Amount in the correct category column
   - **Column K**: Currency (must exactly match the string from B6:B10, including trailing spaces)
3. Do NOT overwrite existing filled rows - append to the next empty row
4. Do NOT modify formula cells (columns L, M, N are formulas)

### Step 6: Fill Exchange Rates

After filling expense rows, automatically look up and fill exchange rates:

1. Identify which foreign currencies are used in the expense rows (check K column values)
2. Fetch rates from the Bank of Israel website:
   ```
   https://www.boi.org.il/en/economic-roles/financial-markets/exchange-rates/
   ```
   Use WebFetch to get the current representative rates (NIS per 1 unit of foreign currency).
3. Fill the exchange rate cells:
   - **D7**: NIS per 1 USD (if USD expenses exist)
   - **D8**: NIS per 1 EUR (if EUR expenses exist)
   - **D9**: NIS per 1 GBP (if GBP expenses exist)
   - **Do NOT touch D11** - it belongs to the per diem section and is managed separately by the user
4. Note: The form says to use "the formal exchange rate of Bank Israel at the date of the expense." If expenses span multiple dates with potentially different rates, use the most recent rate and note this to the user.

### Step 7: Report Results

Display a summary table of what was filled:

```
| Row | Date | Invoice # | Description | Amount | Currency | Category |
|-----|------|-----------|-------------|--------|----------|----------|
| 16  | ... | ...       | ...         | ...    | ...      | Misc.    |
```

Remind the user of fields they still need to fill manually:
- Travel details (Name, Department, Destination, Purpose, Period)
- Any entertainment details (persons entertained, titles)

### Step 8: Clean Up

Remove any temporary files created during image processing (cropped images, etc.).

---

## Tips

- Greek receipts: dates are DD/MM/YYYY format. Look for ΗΜ/ΝΙΑ (date), ΣΥΝΟΛΟ/TOTAL, ΕΚΠΤΩΣΗ/DISCOUNT
- epay terminal receipts: look for ΠΟΣΟ (amount) field for the charged amount
- Always verify the sum: if you can read individual items, check they add up to the stated total
- For receipts with tip: the card terminal receipt shows the final charge, the itemized receipt shows the pre-tip subtotal
