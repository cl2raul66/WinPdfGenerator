#+private
package winpdfgenerator

import "core:fmt"
import "core:strings"
import "core:time"

Pdf_Info :: struct {
	title, author, subject, keywords, creator, producer, creation_date, mod_date: string,
}

write_xmp_object :: proc(sb: ^strings.Builder, id: int, info: Pdf_Info) {
	now := time.now()
	y, m, d := time.date(now)
	h, min, s := time.clock_from_time(now)
	now_iso := fmt.tprintf("%04d-%02d-%02dT%02d:%02d:%02dZ", y, int(m), d, h, min, s)

	create_date := info.creation_date != "" ? info.creation_date : now_iso
	mod_date    := info.mod_date      != "" ? info.mod_date      : now_iso

	xmp_template := `<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/">
 <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
   <dc:format>application/pdf</dc:format>
   <dc:title><rdf:Alt><rdf:li xml:lang="x-default">%s</rdf:li></rdf:Alt></dc:title>
   <dc:creator><rdf:Seq><rdf:li>%s</rdf:li></rdf:Seq></dc:creator>
   <dc:description><rdf:Alt><rdf:li xml:lang="x-default">%s</rdf:li></rdf:Alt></dc:description>
  </rdf:Description>
  <rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/">
   <xmp:CreateDate>%s</xmp:CreateDate>
   <xmp:ModifyDate>%s</xmp:ModifyDate>
   <xmp:CreatorTool>%s</xmp:CreatorTool>
  </rdf:Description>
  <rdf:Description rdf:about="" xmlns:pdf="http://ns.adobe.com/pdf/1.3/">
   <pdf:Producer>%s</pdf:Producer>
   <pdf:Keywords>%s</pdf:Keywords>
  </rdf:Description>
 </rdf:RDF>
</x:xmpmeta>
<?xpacket end="w"?>`

	xmp_content := fmt.aprintf(xmp_template,
		info.title, info.author, info.subject,
		create_date, mod_date, info.creator,
		info.producer, info.keywords,
	)
	defer delete(xmp_content)

	fmt.sbprintf(sb,
		"%d 0 obj\n<< /Type /Metadata /Subtype /XML /Length %d >>\nstream\n%s\nendstream\nendobj\n",
		id, len(xmp_content), xmp_content)
}
