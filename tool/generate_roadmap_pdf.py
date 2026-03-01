from pathlib import Path
import subprocess
import sys

md_path = Path('docs/ai_roadmap_12_maanden.md')
pdf_path = Path('docs/ai_roadmap_12_maanden.pdf')

if not md_path.exists():
    raise SystemExit(f'Markdown niet gevonden: {md_path}')

try:
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
    from reportlab.lib.enums import TA_LEFT
except Exception:
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', '--user', 'reportlab'])
    from reportlab.lib.pagesizes import A4
    from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
    from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
    from reportlab.lib.enums import TA_LEFT

text = md_path.read_text(encoding='utf-8')
lines = text.splitlines()

styles = getSampleStyleSheet()
styles.add(
    ParagraphStyle(
        name='BodyNL',
        parent=styles['BodyText'],
        fontName='Helvetica',
        fontSize=10.5,
        leading=14,
        alignment=TA_LEFT,
    )
)
styles.add(
    ParagraphStyle(
        name='Heading1NL',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=16,
        leading=20,
        spaceAfter=8,
    )
)
styles.add(
    ParagraphStyle(
        name='Heading2NL',
        parent=styles['Heading2'],
        fontName='Helvetica-Bold',
        fontSize=13,
        leading=17,
        spaceBefore=6,
        spaceAfter=4,
    )
)
styles.add(
    ParagraphStyle(
        name='Heading3NL',
        parent=styles['Heading3'],
        fontName='Helvetica-Bold',
        fontSize=11.5,
        leading=15,
        spaceBefore=4,
        spaceAfter=2,
    )
)

story = []
for raw in lines:
    line = raw.rstrip()
    if not line.strip():
        story.append(Spacer(1, 6))
        continue

    esc = (
        line.replace('&', '&amp;')
        .replace('<', '&lt;')
        .replace('>', '&gt;')
    )

    if esc.startswith('# '):
        story.append(Paragraph(esc[2:].strip(), styles['Heading1NL']))
    elif esc.startswith('## '):
        story.append(Paragraph(esc[3:].strip(), styles['Heading2NL']))
    elif esc.startswith('### '):
        story.append(Paragraph(esc[4:].strip(), styles['Heading3NL']))
    elif esc.startswith('- '):
        story.append(Paragraph('- ' + esc[2:].strip(), styles['BodyNL']))
    else:
        story.append(Paragraph(esc, styles['BodyNL']))

pdf = SimpleDocTemplate(
    str(pdf_path),
    pagesize=A4,
    leftMargin=36,
    rightMargin=36,
    topMargin=36,
    bottomMargin=36,
)
pdf.build(story)
print(f'PDF generated: {pdf_path}')
