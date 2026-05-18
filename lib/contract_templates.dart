import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Shared source of truth for the lease / month-to-month rent
// contract templates. Used by manage_listing.dart (landlord-side
// preview / export / custom T&C) and contract_view_screen.dart
// (tenant + landlord post-application).
//
// A landlord can override the defaults per-listing via
// `listings.terms_override` (JSONB array of strings) and/or upload
// a fully custom contract file via `listings.contract_template_url`.

const List<String> kDefaultLeaseTerms = [
  '1. FIXED-TERM LEASE — This Lease Agreement is binding for the duration stated above. Neither party may terminate this agreement before the end date without mutual written consent or valid legal grounds. Early termination by the Tenant shall result in forfeiture of the security deposit unless otherwise agreed in writing.',
  '2. RENT PAYMENT — The Tenant agrees to pay the monthly rent of PHP [Amount] on or before the due date each month. Payments shall be made via [Bank Transfer / GCash / Cash] to [Account Name / Number]. A late payment fee of PHP [Amount] per day shall be charged for payments made after the grace period.',
  '3. SECURITY DEPOSIT — The Tenant has paid a security deposit of PHP [Amount], which shall be held by the Landlord for the duration of the lease. The deposit shall be returned within 30 days after the lease ends, less any deductions for unpaid rent, damages beyond normal wear and tear, or outstanding utility bills.',
  '4. RENT INCREASE — The monthly rent is fixed for the entire lease term and shall not be increased by the Landlord during this period. Any rent adjustment shall only take effect upon renewal of this agreement, subject to prior written notice of at least 60 days before the lease expiry.',
  '5. USE OF PREMISES — The leased premises shall be used exclusively as a private residential dwelling. The Tenant shall not use the property for any commercial, illegal, or immoral activities. Subletting or assignment of this lease requires the prior written consent of the Landlord.',
  '6. UTILITIES & SERVICES — The Tenant shall be responsible for the payment of the following utilities: [Electricity / Water / Internet / Cable]. The following utilities are included in the monthly rent: [specify or write N/A]. The Tenant must settle all utility accounts before vacating the premises.',
  "7. MAINTENANCE & REPAIRS — The Tenant agrees to keep the premises clean and in good condition. Minor repairs costing below PHP [Amount] shall be the Tenant's responsibility. Major structural repairs shall be borne by the Landlord, provided the Tenant gives prompt written notice. The Tenant shall not make alterations or improvements without the Landlord's prior written consent.",
  '8. HOUSE RULES — The Tenant agrees to observe the following house rules: (a) No pets unless explicitly permitted in writing; (b) No excessive noise between [10:00 PM – 7:00 AM]; (c) Guests are allowed but overnight guests staying more than [7 consecutive days] must be declared; (d) Proper waste disposal practices must be observed; (e) Common areas must be kept clean and unobstructed.',
  '9. LEASE RENEWAL — At least 60 days before the lease expiry, either party must notify the other of their intention to renew or terminate. If no notice is given, the lease shall convert to a month-to-month rental agreement under the same terms, subject to rent adjustment with 30-day notice.',
  '10. TERMINATION & EVICTION — The Landlord may terminate this lease and require the Tenant to vacate under the following grounds: (a) Non-payment of rent for two or more consecutive months; (b) Serious breach of any provision of this agreement; (c) Use of the property for illegal activities. Eviction proceedings shall follow the applicable provisions of Philippine law, including Republic Act No. 9653 (Rent Control Act).',
  '11. GOVERNING LAW — This Agreement shall be governed by the laws of the Republic of the Philippines. Any dispute arising from this Agreement shall first be resolved through amicable settlement. If unresolved, disputes shall be submitted to the proper courts of [City / Municipality], Philippines.',
  '12. ENTIRE AGREEMENT — This Agreement constitutes the entire agreement between the parties and supersedes all prior discussions, representations, or agreements. Any amendment must be in writing and signed by both parties.',
];

const List<String> kDefaultRentTerms = [
  '1. MONTH-TO-MONTH TENANCY — This Rental Agreement creates a month-to-month tenancy commencing on the start date above. The agreement shall automatically renew each month unless terminated by either party with the required written notice. There is no fixed end date; the tenancy continues indefinitely until properly terminated.',
  "2. TERMINATION NOTICE — Either party may terminate this Agreement by providing at least 30 days written notice to the other party. Notice must be delivered in person, by registered mail, or via the platform's official messaging system. The tenancy ends on the last day of the notice period. The Tenant remains liable for rent during the notice period regardless of early vacating.",
  '3. RENT PAYMENT — The Tenant agrees to pay the monthly rent of PHP [Amount] on or before the due date each month. Payments shall be made via [Bank Transfer / GCash / Cash] to [Account Name / Number]. A late payment fee of PHP [Amount] per day shall be charged after the grace period.',
  '4. RENT ADJUSTMENT — The Landlord reserves the right to adjust the monthly rent by providing the Tenant with at least 30 days prior written notice. The Tenant may accept the new rent or terminate the agreement in accordance with Clause 2. No adjustment shall violate applicable rent control regulations under R.A. 9653.',
  "5. SECURITY DEPOSIT — The Tenant has paid a security deposit of PHP [Amount]. The deposit shall be returned within 30 days after the Tenant fully vacates the premises, less lawful deductions for unpaid rent, damages, or unpaid utilities. The deposit shall not be applied as payment for the last month's rent without written consent of the Landlord.",
  "6. USE OF PREMISES — The premises shall be used exclusively as a private residential dwelling. Commercial use, subletting, and assignment are prohibited without the Landlord's prior written consent. The Tenant shall comply with all applicable laws, ordinances, and homeowners association rules.",
  '7. UTILITIES & SERVICES — The Tenant shall be responsible for: [Electricity / Water / Internet / Cable]. Included in the monthly rent: [specify or write N/A]. All utility accounts must be settled in full before the Tenant vacates the premises.',
  "8. MAINTENANCE & REPAIRS — The Tenant shall maintain the premises in a clean and habitable condition. Minor repairs below PHP [Amount] are the Tenant's responsibility. The Tenant must report any significant damage or needed repairs to the Landlord promptly. No structural alterations may be made without written approval.",
  '9. HOUSE RULES — The Tenant agrees to: (a) Refrain from creating excessive noise between [10:00 PM – 7:00 AM]; (b) Properly dispose of garbage as per local schedules; (c) Declare guests staying beyond [7 consecutive days]; (d) Not keep pets unless specifically permitted in writing; (e) Maintain shared areas in clean condition.',
  '10. LANDLORD ACCESS — The Landlord may enter the premises for inspection, repairs, or showing to prospective tenants with at least 24 hours prior notice, except in cases of emergency where immediate entry may be required to prevent damage or harm.',
  '11. NON-PAYMENT & BREACH — Failure to pay rent for two consecutive months, or serious breach of any provision of this Agreement, shall entitle the Landlord to terminate this Agreement and initiate eviction proceedings in accordance with Philippine law.',
  '12. GOVERNING LAW — This Agreement shall be governed by the laws of the Republic of the Philippines, including R.A. 9653 (Rent Control Act of 2009). Disputes shall first be resolved through amicable settlement; otherwise, submitted to courts of [City / Municipality], Philippines.',
  '13. ENTIRE AGREEMENT — This Agreement represents the full understanding between the parties. Any amendment must be made in writing and signed by both parties. This Agreement supersedes any prior oral or written representations.',
];

/// `type` is 'lease' (fixed-term) or 'rent' (month-to-month).
List<String> defaultTermsForType(String type) =>
    type == 'rent' ? kDefaultRentTerms : kDefaultLeaseTerms;

bool isLeaseType(String? type) => (type ?? 'lease') != 'rent';

String contractTitleForType(String type) => isLeaseType(type)
    ? 'RESIDENTIAL LEASE AGREEMENT'
    : 'MONTH-TO-MONTH RENTAL AGREEMENT';

/// Strongly-typed bundle of the form fields the contract templates
/// know how to render. All fields are nullable / blank-tolerant —
/// any empty value renders as `[ … ]` placeholder so the file stays
/// editable.
class ContractTemplateInput {
  final String listingType;
  final List<String> terms;
  final String? landlordName;
  final String? landlordContact;
  final String? tenantName;
  final String? tenantContact;
  final String? propertyTitle;
  final String? propertyAddress;
  final String? propertyType;
  final String? leaseStartDate;
  final String? leaseEndDate;
  final String? leaseDuration;
  final String? monthlyRent;
  final String? securityDeposit;
  final String? advancePayment;
  final String? paymentDueDate;
  final String? gracePeriod;
  final String? agreementDate;

  const ContractTemplateInput({
    required this.listingType,
    required this.terms,
    this.landlordName,
    this.landlordContact,
    this.tenantName,
    this.tenantContact,
    this.propertyTitle,
    this.propertyAddress,
    this.propertyType,
    this.leaseStartDate,
    this.leaseEndDate,
    this.leaseDuration,
    this.monthlyRent,
    this.securityDeposit,
    this.advancePayment,
    this.paymentDueDate,
    this.gracePeriod,
    this.agreementDate,
  });
}

/// Build a plain-text contract suitable for clipboard / fallback.
/// Mirrors the PDF layout for read-only contexts.
String buildContractTemplateText(ContractTemplateInput input) {
  final isLease = isLeaseType(input.listingType);
  final buf = StringBuffer()
    ..writeln(contractTitleForType(input.listingType))
    ..writeln('=' * 60)
    ..writeln('This Agreement is entered into on: ${_or(input.agreementDate, "____________________")}')
    ..writeln('CONTRACT TYPE: ${isLease ? "FIXED-TERM LEASE" : "MONTH-TO-MONTH RENTAL"}')
    ..writeln()
    ..writeln('PARTIES & PROPERTY DETAILS')
    ..writeln('-' * 60)
    ..writeln('Landlord / Lessor:    ${_or(input.landlordName, "[Landlord Full Name]")}')
    ..writeln('Tenant / Lessee:      ${_or(input.tenantName, "[Tenant Full Name]")}')
    ..writeln('Landlord Contact:     ${_or(input.landlordContact, "[Phone / Email]")}')
    ..writeln('Tenant Contact:       ${_or(input.tenantContact, "[Phone / Email]")}')
    ..writeln('Property Address:     ${_or(input.propertyAddress, "[Unit No., Building, Street, City]")}')
    ..writeln('Property Type:        ${_or(input.propertyType, "[Apartment / House / Condo / Studio]")}')
    ..writeln(isLease
        ? 'Lease Start Date:     ${_or(input.leaseStartDate, "[Month DD, YYYY]")}'
        : 'Rental Start Date:    ${_or(input.leaseStartDate, "[Month DD, YYYY]")}')
    ..writeln(isLease
        ? 'Lease End Date:       ${_or(input.leaseEndDate, "[Month DD, YYYY]")}'
        : 'Initial Term:         Month-to-Month (auto-renews)')
    ..writeln(isLease
        ? 'Lease Duration:       ${_or(input.leaseDuration, "[6 / 12 / 24 months]")}'
        : '')
    ..writeln('Monthly Rent (PHP):   ${_or(input.monthlyRent, "[Amount]")}')
    ..writeln('Security Deposit:     ${_or(input.securityDeposit, "[Amount]")}')
    ..writeln('Advance Rent:         ${_or(input.advancePayment, "[Amount]")}')
    ..writeln('Payment Due Date:     ${_or(input.paymentDueDate, "[Day of the month, e.g., 5th]")}')
    ..writeln('Grace Period:         ${_or(input.gracePeriod, "[e.g., 5 days after due date]")}')
    ..writeln(isLease ? '' : 'Termination Notice:   30 days written notice by either party')
    ..writeln()
    ..writeln('TERMS AND CONDITIONS')
    ..writeln('-' * 60);

  for (final t in input.terms) {
    buf
      ..writeln()
      ..writeln(t);
  }

  buf
    ..writeln()
    ..writeln('SIGNATURES')
    ..writeln('-' * 60)
    ..writeln('Landlord Signature: __________________________')
    ..writeln('Printed Name:       __________________________')
    ..writeln('Date:               __________________________')
    ..writeln()
    ..writeln('Tenant Signature:   __________________________')
    ..writeln('Printed Name:       __________________________')
    ..writeln('Date:               __________________________');

  return buf.toString();
}

String _or(String? value, String fallback) {
  if (value == null) return fallback;
  final trimmed = value.trim();
  return trimmed.isEmpty ? fallback : trimmed;
}

// ─────────────────────────────────────────────
// PDF GENERATION
// ─────────────────────────────────────────────
// Mirrors the design supplied by the PDF templates the landlord
// shared: a colored header bar (navy for lease, green for rent),
// a tinted parties-and-property table, plain T&C body, and a
// signature block.

const PdfColor _kLeaseHeaderBg = PdfColor.fromInt(0xFF1F3A68);
const PdfColor _kLeaseTableBg = PdfColor.fromInt(0xFFE8EEF7);
const PdfColor _kRentHeaderBg = PdfColor.fromInt(0xFF1E5135);
const PdfColor _kRentTableBg = PdfColor.fromInt(0xFFE3F1E7);
const PdfColor _kAccent = PdfColor.fromInt(0xFFE8735A); // brand kCoral
const PdfColor _kFooterText = PdfColor.fromInt(0xFF888888);
const PdfColor _kLabelColor = PdfColor.fromInt(0xFF6B7A99);
const PdfColor _kBodyText = PdfColor.fromInt(0xFF1F2937);

Future<pw.Document> buildContractPdf(ContractTemplateInput input) async {
  final isLease = isLeaseType(input.listingType);
  final headerBg = isLease ? _kLeaseHeaderBg : _kRentHeaderBg;
  final tableBg = isLease ? _kLeaseTableBg : _kRentTableBg;

  final pdf = pw.Document(
    title: contractTitleForType(input.listingType),
    author: input.landlordName ?? 'ViewxRent',
  );

  final base = await _loadBaseFont();
  final bold = await _loadBoldFont();
  final theme = pw.ThemeData.withFont(base: base, bold: bold);

  // Build the parties + property rows up-front so the same data
  // structure stays close to the PDF templates the landlord gave us.
  final detailRows = <List<String>>[
    ['LANDLORD / LESSOR', _or(input.landlordName, '[Landlord Full Name]'),
     'TENANT / LESSEE', _or(input.tenantName, '[Tenant Full Name]')],
    ['LANDLORD CONTACT', _or(input.landlordContact, '[Phone / Email]'),
     'TENANT CONTACT', _or(input.tenantContact, '[Phone / Email]')],
    ['PROPERTY ADDRESS', _or(input.propertyAddress, '[Unit No., Building, Street, City]'),
     'PROPERTY TYPE', _or(input.propertyType, '[Apartment / House / Condo / Studio]')],
    if (isLease) ...[
      [
        'LEASE START DATE', _or(input.leaseStartDate, '[Month DD, YYYY]'),
        'LEASE END DATE', _or(input.leaseEndDate, '[Month DD, YYYY]'),
      ],
      [
        'LEASE DURATION', _or(input.leaseDuration, '[6 months / 12 months / 24 months]'),
        'MONTHLY RENT (PHP)', 'PHP ${_or(input.monthlyRent, "[Amount in figures]")}',
      ],
      [
        'SECURITY DEPOSIT (PHP)', 'PHP ${_or(input.securityDeposit, "[Amount — typically 1–2 months rent]")}',
        'ADVANCE RENT (PHP)', 'PHP ${_or(input.advancePayment, "[Amount — typically 1–2 months]")}',
      ],
      [
        'PAYMENT DUE DATE', _or(input.paymentDueDate, '[Day of the month, e.g., 5th]'),
        'GRACE PERIOD', _or(input.gracePeriod, '[e.g., 5 days after due date]'),
      ],
    ] else ...[
      [
        'RENTAL START DATE', _or(input.leaseStartDate, '[Month DD, YYYY]'),
        'INITIAL TERM', 'Month-to-Month (auto-renews)',
      ],
      [
        'MONTHLY RENT (PHP)', 'PHP ${_or(input.monthlyRent, "[Amount in figures]")}',
        'SECURITY DEPOSIT (PHP)', 'PHP ${_or(input.securityDeposit, "[Amount — typically 1 month rent]")}',
      ],
      [
        'ADVANCE RENT (PHP)', 'PHP ${_or(input.advancePayment, "[Amount — typically 1 month]")}',
        'PAYMENT DUE DATE', _or(input.paymentDueDate, '[Day of the month, e.g., 5th]'),
      ],
      [
        'GRACE PERIOD', _or(input.gracePeriod, '[e.g., 5 days after due date]'),
        'TERMINATION NOTICE', '30 days written notice by either party',
      ],
    ],
  ];

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.letter.copyWith(
        marginLeft: 48,
        marginRight: 48,
        marginTop: 36,
        marginBottom: 48,
      ),
      theme: theme,
      build: (ctx) => [
        _pdfHeader(
          title: contractTitleForType(input.listingType),
          contractType: isLease ? 'FIXED-TERM LEASE' : 'MONTH-TO-MONTH RENTAL',
          agreementDate: _or(input.agreementDate, '____________________________'),
          headerBg: headerBg,
        ),
        pw.SizedBox(height: 18),
        _pdfSectionTitle('PARTIES & PROPERTY DETAILS', headerBg),
        pw.SizedBox(height: 10),
        _pdfDetailsTable(rows: detailRows, fillColor: tableBg),
        pw.SizedBox(height: 18),
        _pdfDivider(),
        pw.SizedBox(height: 12),
        _pdfSectionTitle('TERMS AND CONDITIONS', headerBg),
        pw.SizedBox(height: 10),
        ..._pdfTerms(input.terms),
        pw.SizedBox(height: 18),
        _pdfDivider(),
        pw.SizedBox(height: 12),
        _pdfSectionTitle('SIGNATURES', headerBg),
        pw.SizedBox(height: 8),
        pw.Text(
          'By signing below, both parties acknowledge that they have read, '
          'understood, and agreed to all the terms and conditions of this '
          '${isLease ? "Lease" : "Month-to-Month Rental"} Agreement.',
          style: const pw.TextStyle(fontSize: 10, color: _kBodyText, height: 1.45),
        ),
        pw.SizedBox(height: 28),
        _pdfSignatureRow(input),
        if (isLease) ...[
          pw.SizedBox(height: 16),
          _pdfNotaryBlock(),
        ],
        pw.SizedBox(height: 22),
        pw.Center(
          child: pw.Text(
            'This is a template contract. Consult a licensed attorney before use. '
            'Subject to Philippine law including R.A. 9653 (Rent Control Act of 2009).',
            style: pw.TextStyle(
              fontSize: 8,
              color: _kFooterText,
              fontStyle: pw.FontStyle.italic,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ),
      ],
    ),
  );

  return pdf;
}

// Default fonts ship with the `pdf` package — no asset round-trip
// needed. We still wrap the loader so callers can swap in a brand
// font later via rootBundle without touching call sites.
Future<pw.Font> _loadBaseFont() async {
  try {
    return pw.Font.helvetica();
  } catch (_) {
    final raw = await rootBundle.load('packages/pdf/assets/Helvetica.ttf');
    return pw.Font.ttf(raw);
  }
}

Future<pw.Font> _loadBoldFont() async {
  try {
    return pw.Font.helveticaBold();
  } catch (_) {
    final raw = await rootBundle.load('packages/pdf/assets/Helvetica-Bold.ttf');
    return pw.Font.ttf(raw);
  }
}

pw.Widget _pdfHeader({
  required String title,
  required String contractType,
  required String agreementDate,
  required PdfColor headerBg,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        decoration: pw.BoxDecoration(color: headerBg),
        padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: pw.Center(
          child: pw.Text(
            title,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
      pw.Container(
        decoration: pw.BoxDecoration(color: headerBg),
        padding: const pw.EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'This Agreement is entered into on:',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 9,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    agreementDate,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 10,
                      decoration: pw.TextDecoration.underline,
                    ),
                  ),
                ],
              ),
            ),
            pw.Text(
              'CONTRACT TYPE: $contractType',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
      pw.Container(height: 2, color: _kAccent),
    ],
  );
}

pw.Widget _pdfSectionTitle(String label, PdfColor color) {
  return pw.Text(
    label,
    style: pw.TextStyle(
      fontSize: 12,
      fontWeight: pw.FontWeight.bold,
      color: color,
      letterSpacing: 0.4,
    ),
  );
}

pw.Widget _pdfDivider() => pw.Container(
      height: 1,
      color: PdfColors.grey400,
    );

pw.Widget _pdfDetailsTable({
  required List<List<String>> rows,
  required PdfColor fillColor,
}) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(2),
      color: fillColor,
    ),
    padding: const pw.EdgeInsets.all(8),
    child: pw.Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          if (i > 0) pw.SizedBox(height: 6),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(child: _pdfDetailCell(rows[i][0], rows[i][1])),
              pw.SizedBox(width: 14),
              pw.Expanded(child: _pdfDetailCell(rows[i][2], rows[i][3])),
            ],
          ),
        ],
      ],
    ),
  );
}

pw.Widget _pdfDetailCell(String label, String value) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        label,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: _kLabelColor,
          letterSpacing: 0.4,
        ),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        value,
        style: const pw.TextStyle(
          fontSize: 10,
          color: _kBodyText,
        ),
      ),
    ],
  );
}

List<pw.Widget> _pdfTerms(List<String> terms) {
  final widgets = <pw.Widget>[];
  for (final t in terms) {
    final parts = _splitClauseHeader(t);
    widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                parts.header,
                style: pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: _kBodyText,
                ),
              ),
              if (parts.body.isNotEmpty) ...[
                pw.SizedBox(height: 3),
                pw.Text(
                  parts.body,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: _kBodyText,
                    lineSpacing: 1.6,
                  ),
                  textAlign: pw.TextAlign.justify,
                ),
              ],
            ],
          ),
        ),
    );
  }
  return widgets;
}

class _ClauseParts {
  final String header;
  final String body;
  const _ClauseParts(this.header, this.body);
}

_ClauseParts _splitClauseHeader(String clause) {
  // Default-shipped clauses have the shape "1. TITLE — body…".
  // If the landlord wrote a custom clause without the dash, treat
  // the whole string as body and synthesize a generic header.
  final dashIndex = clause.indexOf('—');
  if (dashIndex == -1) return _ClauseParts(clause.trim(), '');
  final header = clause.substring(0, dashIndex).trim();
  final body = clause.substring(dashIndex + 1).trim();
  return _ClauseParts(header, body);
}

pw.Widget _pdfSignatureRow(ContractTemplateInput input) {
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: _pdfSignatureBlock(
          role: "Landlord's Signature",
          printedName: input.landlordName,
        ),
      ),
      pw.SizedBox(width: 18),
      pw.Expanded(
        child: _pdfSignatureBlock(
          role: "Tenant's Signature",
          printedName: input.tenantName,
        ),
      ),
    ],
  );
}

pw.Widget _pdfSignatureBlock({
  required String role,
  String? printedName,
}) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(height: 1, color: PdfColors.grey700),
      pw.SizedBox(height: 4),
      pw.Center(
        child: pw.Text(
          role,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: _kBodyText,
          ),
        ),
      ),
      pw.SizedBox(height: 12),
      pw.Text(
        'Printed Name: ${_or(printedName, "_______________________")}',
        style: const pw.TextStyle(fontSize: 9, color: _kBodyText),
      ),
      pw.SizedBox(height: 6),
      pw.Text(
        'Date: ________________________________',
        style: const pw.TextStyle(fontSize: 9, color: _kBodyText),
      ),
    ],
  );
}

pw.Widget _pdfNotaryBlock() {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
    ),
    child: pw.Text(
      'Subscribed and sworn to before me this _____ day of __________, 20___, '
      'at ________________________, Philippines. '
      'Notary Public: _________________________ '
      'Doc. No. _____  Commission Expires: _____________________  '
      'Page No. _____  Book No. _____  Series of 20___',
      style: const pw.TextStyle(fontSize: 9, color: _kBodyText, lineSpacing: 1.6),
    ),
  );
}
