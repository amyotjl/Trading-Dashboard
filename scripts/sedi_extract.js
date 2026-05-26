/**
 * SEDI Insider Transaction Extractor
 *
 * Injected into the browser by the scheduled task after the results page has loaded.
 * Returns the full CSV string via window._sediCsv, ready for clipboard copy.
 *
 * Entry points:
 *   sediSetupSearch(yesterdayStr)  — call on the search-criteria page
 *   sediExtract()                  — call on the results page (after remarks dialog)
 *
 * yesterdayStr format: "YYYY-MM-DD"
 */

(function () {

  // ── Helpers ────────────────────────────────────────────────────────────────

  function selectByText(selectEl, text) {
    for (const opt of selectEl.options) {
      if (opt.text.trim() === text || opt.value === text) {
        selectEl.value = opt.value;
        selectEl.dispatchEvent(new Event('change', { bubbles: true }));
        return true;
      }
    }
    return false;
  }

  const MONTH_NAMES = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];

  function csvEsc(v) {
    if (v == null) return '';
    const s = String(v).replace(/\r?\n/g, ' ').trim();
    return (s.includes(',') || s.includes('"')) ? '"' + s.replace(/"/g, '""') + '"' : s;
  }

  // ── Setup: fill the search form and submit ─────────────────────────────────

  window.sediSetupSearch = function (yesterdayStr) {
    const [year, month, day] = yesterdayStr.split('-');
    const monthName = MONTH_NAMES[parseInt(month, 10) - 1];

    // Date type: "Date of transaction"
    const selects = document.querySelectorAll('select');
    let dateTypeSet = false;
    for (const sel of selects) {
      for (const opt of sel.options) {
        if (opt.text.trim() === 'Date of transaction') {
          sel.value = opt.value;
          sel.dispatchEvent(new Event('change', { bubbles: true }));
          dateTypeSet = true;
          break;
        }
      }
      if (dateTypeSet) break;
    }

    // From/To month+day+year — the page has two sets of month/day selects
    const monthSelects = Array.from(selects).filter(s =>
      Array.from(s.options).some(o => o.text.trim() === 'January')
    );
    const daySelects = Array.from(selects).filter(s =>
      Array.from(s.options).some(o => o.text.trim() === '31' || o.value === '31')
    );

    monthSelects.forEach(s => selectByText(s, monthName));
    daySelects.forEach(s => selectByText(s, String(parseInt(day, 10))));

    // Only fill the two year inputs (YEAR_FROM_PUBLIC / YEAR_TO_PUBLIC).
    // Those inputs have maxLength=4; the issuer-name field (maxLength=120)
    // and the NAICS field (maxLength=6) must be left untouched.
    const yearInputs = Array.from(document.querySelectorAll('input[type="text"], input:not([type])'))
      .filter(inp => inp.maxLength === 4);
    yearInputs.forEach(inp => {
      inp.value = year;
      inp.dispatchEvent(new Event('input', { bubbles: true }));
      inp.dispatchEvent(new Event('change', { bubbles: true }));
    });

    return `Search form filled: Date of transaction, ${monthName} ${parseInt(day,10)}, ${year}`;
  };

  // ── Extract: parse the results page and build CSV ─────────────────────────

  window.sediExtract = function () {
    const bodyText = document.body.innerText;
    const lines = bodyText.split('\n').map(l => l.trim()).filter(l => l.length > 0);
    const startIdx = lines.findIndex(l => l.startsWith('Issuer name:'));

    if (startIdx === -1) {
      return { error: 'Results page not detected — "Issuer name:" not found.' };
    }

    const transactions = [];
    let currentIssuer = '', currentInsider = '', currentRelationship = '', currentSecurity = '';
    let pendingTx = null;

    for (let i = startIdx; i < lines.length; i++) {
      const line = lines[i];
      const parts = line.split('\t');

      if (line.startsWith('Issuer name:')) {
        currentIssuer = parts.slice(1).join(' ').trim();
      } else if (line.startsWith('Insider name:')) {
        currentInsider = parts.slice(1).join(' ').trim();
      } else if (line.startsWith("Insider's Relationship to Issuer:")) {
        currentRelationship = parts.slice(1).join(' ').trim();
      } else if (line.startsWith('Security designation:')) {
        currentSecurity = parts.slice(1).join(' ').trim();
      } else if (/^\d{7}\t/.test(line)) {
        pendingTx = {
          issuer: currentIssuer,
          insider: currentInsider,
          relationship: currentRelationship,
          security: currentSecurity,
          txId: parts[0],
          dateOfTx: parts[1],
          dateOfFiling: parts[2],
          ownershipType: (parts[3] || '').replace(/:$/, '').trim(),
          registeredHolder: '',
          natureOfTx: '',
          numberAcqDisp: '',
          unitPrice: '',
          closingBalance: '',
          insiderCalcBalance: '',
          conversionPrice: '',
          dateOfExpiry: '',
          underlyingSecurity: '',
          equivNumber: '',
          equivClosingBalance: '',
          remarks: ''
        };
      } else if (
        pendingTx &&
        !line.startsWith('General remarks:') &&
        !line.startsWith('Issuer name:') &&
        !line.startsWith('Insider name:') &&
        !line.startsWith('Security designation:') &&
        !line.startsWith('Ceased to be') &&
        !line.startsWith("Insider's Relationship")
      ) {
        // Determine whether line starts with registered holder or nature code
        let di = 0;
        if (parts[0] && /^\d+\s*-/.test(parts[0])) {
          di = 0;
        } else if (parts[1] && /^\d+\s*-/.test(parts[1])) {
          pendingTx.registeredHolder = parts[0].trim();
          di = 1;
        }
        pendingTx.natureOfTx          = (parts[di]   || '').trim();
        pendingTx.numberAcqDisp        = (parts[di+1] || '').trim();
        pendingTx.unitPrice            = (parts[di+2] || '').trim();
        pendingTx.closingBalance       = (parts[di+3] || '').trim();
        pendingTx.insiderCalcBalance   = (parts[di+4] || '').trim();
        pendingTx.conversionPrice      = (parts[di+5] || '').trim();
        pendingTx.dateOfExpiry         = (parts[di+6] || '').trim();
        pendingTx.underlyingSecurity   = (parts[di+7] || '').trim();
        pendingTx.equivNumber          = (parts[di+8] || '').trim();
        pendingTx.equivClosingBalance  = (parts[di+9] || '').trim();
        transactions.push(pendingTx);
        pendingTx = null;
      } else if (line.startsWith('General remarks:') && transactions.length > 0) {
        transactions[transactions.length - 1].remarks = parts.slice(1).join(' ').trim();
      }
    }

    // Build CSV
    const headers = [
      'Transaction ID', 'Issuer Name', 'Insider Name', 'Insider Relationship to Issuer',
      'Security Designation', 'Date of Transaction', 'Date of Filing', 'Ownership Type',
      'Registered Holder', 'Nature of Transaction', 'Number or Value Acquired or Disposed',
      'Unit Price or Exercise Price', 'Closing Balance', 'Insider Calculated Balance',
      'Conversion or Exercise Price', 'Date of Expiry or Maturity',
      'Underlying Security Designation', 'Equivalent Number or Value Acquired or Disposed',
      'Equivalent Closing Balance', 'Remarks'
    ];

    const rows = transactions.map(t => [
      t.txId, t.issuer, t.insider, t.relationship, t.security,
      t.dateOfTx, t.dateOfFiling, t.ownershipType, t.registeredHolder,
      t.natureOfTx, t.numberAcqDisp, t.unitPrice, t.closingBalance,
      t.insiderCalcBalance, t.conversionPrice, t.dateOfExpiry,
      t.underlyingSecurity, t.equivNumber, t.equivClosingBalance, t.remarks
    ].map(csvEsc).join(','));

    window._sediCsv = [headers.join(','), ...rows].join('\n');
    window._sediTransactions = transactions;

    return {
      ok: true,
      rowCount: transactions.length,
      preview: rows[0] || '(no rows)'
    };
  };

  return 'SEDI extractor loaded. Call sediSetupSearch("YYYY-MM-DD") or sediExtract().';
})();
