import os
import subprocess
import zipfile
import re
import srs_content
import generate_svgs

print("=== Generating Full SRS Document with Embedded Diagrams ===")

# 1. Define SVGs
svgs = {
    'diag_swimlane.svg': generate_svgs.get_swimlane_svg(),
    'diag_use_case.svg': generate_svgs.get_use_case_svg(),
    'diag_deletion_flow.svg': generate_svgs.get_deletion_flow_svg(),
    'diag_components.svg': generate_svgs.get_components_svg(),
    'diag_erd.svg': generate_svgs.get_erd_svg(),
}

# 2. Save and convert SVGs to PNG
pngs = {}
for svg_name, svg_content in svgs.items():
    svg_path = f"docs/{svg_name}"
    png_name = svg_name.replace('.svg', '.png')
    png_path = f"docs/{png_name}"
    with open(svg_path, 'w', encoding='utf-8') as f:
        f.write(svg_content)
    subprocess.run(['sips', '-s', 'format', 'png', svg_path, '--out', png_path], check=True, stdout=subprocess.DEVNULL)
    pngs[png_name] = png_path
    print(f"Converted {svg_name} -> {png_name}")

# 3. Build full HTML
full_html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
{srs_content.get_html_style()}
</head>
<body>
{srs_content.get_cover_and_ch1_to_ch3()}
{srs_content.get_ch4_to_ch6()}
{srs_content.get_ch7_to_ch8()}
{srs_content.get_ch9_to_ch13()}
</body>
</html>
"""

temp_html_path = "docs/srs_temp.html"
docx_path = "docs/SRS.docx"

with open(temp_html_path, 'w', encoding='utf-8') as f:
    f.write(full_html)

print("Converting HTML to baseline DOCX via textutil...")
subprocess.run(['textutil', '-convert', 'docx', temp_html_path, '-output', docx_path], check=True)

# 4. Unpack and inject images safely
print("Unpacking DOCX and injecting DrawingML diagrams safely...")
with zipfile.ZipFile(docx_path, 'r') as zin:
    files = {name: zin.read(name) for name in zin.namelist()}

# Update Content_Types
ct = files['[Content_Types].xml'].decode('utf-8')
if 'Extension="png"' not in ct:
    ct = ct.replace('</Types>', '<Default Extension="png" ContentType="image/png"/></Types>')
files['[Content_Types].xml'] = ct.encode('utf-8')

# Update document.xml.rels
rels = files['word/_rels/document.xml.rels'].decode('utf-8')
doc_xml = files['word/document.xml'].decode('utf-8')

diagram_mappings = [
    ('[[DIAG_SWIMLANE]]', 'diag_swimlane.png', 'rIdSwimlane', 'media/diag_swimlane.png', 5600000, 3640000),
    ('[[DIAG_USE_CASE]]', 'diag_use_case.png', 'rIdUseCase', 'media/diag_use_case.png', 5600000, 3472000),
    ('[[DIAG_DELETION_FLOW]]', 'diag_deletion_flow.png', 'rIdDeletionFlow', 'media/diag_deletion_flow.png', 5400000, 3052000),
    ('[[DIAG_COMPONENTS]]', 'diag_components.png', 'rIdComponents', 'media/diag_components.png', 5600000, 3360000),
    ('[[DIAG_ERD]]', 'diag_erd.png', 'rIdErd', 'media/diag_erd.png', 5600000, 3472000),
]

for placeholder, png_filename, r_id, target_media, cx, cy in diagram_mappings:
    png_file_path = f"docs/{png_filename}"
    if os.path.exists(png_file_path):
        with open(png_file_path, 'rb') as f:
            files['word/' + target_media] = f.read()
        
        # Add rel
        rel_entry = f'<Relationship Id="{r_id}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="{target_media}"/>'
        rels = rels.replace('</Relationships>', rel_entry + '</Relationships>')
        
        # Build drawing XML
        draw_xml = f'''<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0"><wp:extent cx="{cx}" cy="{cy}"/><wp:docPr id="{r_id}" name="{target_media}"/><a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"><a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture"><pic:nvPicPr><pic:cNvPr id="{r_id}" name="{target_media}"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" r:embed="{r_id}"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="{cx}" cy="{cy}"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>'''
        
        pos = doc_xml.find(placeholder)
        if pos != -1:
            r_start = doc_xml.rfind('<w:r>', 0, pos)
            r_end = doc_xml.find('</w:r>', pos) + len('</w:r>')
            if r_start != -1 and r_end != -1:
                doc_xml = doc_xml[:r_start] + draw_xml + doc_xml[r_end:]
                print(f"Successfully injected {png_filename} at exact placeholder position!")
            else:
                print(f"Warning: Could not find enclosing <w:r> for {placeholder}")
        else:
            print(f"Warning: Placeholder {placeholder} not found in doc_xml")

files['word/_rels/document.xml.rels'] = rels.encode('utf-8')
files['word/document.xml'] = doc_xml.encode('utf-8')

# 5. Repack DOCX
with zipfile.ZipFile(docx_path, 'w', compression=zipfile.ZIP_DEFLATED) as zout:
    for name, content in files.items():
        zout.writestr(name, content)

print("Repacked DOCX successfully!")

# 6. Cleanup temporary files
os.remove(temp_html_path)
for svg_name in svgs:
    svg_p = f"docs/{svg_name}"
    if os.path.exists(svg_p):
        os.remove(svg_p)
for png_name in pngs:
    png_p = f"docs/{png_name}"
    if os.path.exists(png_p):
        os.remove(png_p)

print("Temporary files cleaned up.")
print(f"Final SRS Document generated at: {docx_path}")
