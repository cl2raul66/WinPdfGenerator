#+private
package winpdfgenerator

import "core:fmt"
import "core:strings"
import "core:time"

// NOTA: En PDF 2.0 el diccionario Info está mayoritariamente deprecado (§14.3.3).
// Los metadatos deben residir en el stream XMP. Se mantiene por retrocompatibilidad.
Pdf_Info :: struct {
	title:         string,
	author:        string,
	subject:       string,
	keywords:      string,
	creator:       string,
	producer:      string,
	creation_date: string, // Formato D:YYYYMMDDHHmmSSOHH'mm' (§7.9.4)
	mod_date:      string,
	trapped:       Maybe(bool),
}

pdf_date_now :: proc() -> string {
	now := time.now()
	year, month, day := time.date(now)
	hour, min, sec   := time.clock_from_time(now)
	return fmt.aprintf("D:%04d%02d%02d%02d%02d%02d+00'00'",
		year, int(month), day, hour, min, sec)
}

// CORRECCIÓN: os.Handle no disponible. Cambiado a ^strings.Builder.
// El llamador escribe el contenido del builder al archivo.
write_info_object :: proc(sb: ^strings.Builder, id: int, info: Pdf_Info) {
	creation := info.creation_date != "" ? info.creation_date : pdf_date_now()
	mod      := info.mod_date      != "" ? info.mod_date      : creation
	producer := info.producer      != "" ? info.producer      : "WinPdfGenerator"

	fmt.sbprintf(sb, "%d 0 obj\n<<\n", id)
	if info.title    != "" { fmt.sbprintf(sb, "  /Title (%s)\n",    info.title) }
	if info.author   != "" { fmt.sbprintf(sb, "  /Author (%s)\n",   info.author) }
	if info.subject  != "" { fmt.sbprintf(sb, "  /Subject (%s)\n",  info.subject) }
	if info.keywords != "" { fmt.sbprintf(sb, "  /Keywords (%s)\n", info.keywords) }
	if info.creator  != "" { fmt.sbprintf(sb, "  /Creator (%s)\n",  info.creator) }
	fmt.sbprintf(sb, "  /Producer (%s)\n",     producer)
	fmt.sbprintf(sb, "  /CreationDate (%s)\n", creation)
	fmt.sbprintf(sb, "  /ModDate (%s)\n",      mod)
	if trapped, ok := info.trapped.?; ok {
		fmt.sbprintf(sb, "  /Trapped /%s\n", trapped ? "True" : "False")
	} else {
		fmt.sbprintf(sb, "  /Trapped /Unknown\n")
	}
	fmt.sbprintf(sb, ">>\nendobj\n")
}

write_xmp_object :: proc(sb: ^strings.Builder, id: int, info: Pdf_Info) {
	creation := info.creation_date != "" ? info.creation_date : pdf_date_now()
	mod      := info.mod_date      != "" ? info.mod_date      : creation
	iso_creation := pdf_date_to_iso8601(creation)
	iso_mod      := pdf_date_to_iso8601(mod)
	producer     := info.producer != "" ? info.producer : "WinPdfGenerator"

	xmp_template := `<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/">
 <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
  <rdf:Description rdf:about="" xmlns:pdf="http://ns.adobe.com/pdf/1.3/">
   <pdf:Producer>%s</pdf:Producer>
   <pdf:Keywords>%s</pdf:Keywords>
  </rdf:Description>
  <rdf:Description rdf:about="" xmlns:xmp="http://ns.adobe.com/xap/1.0/">
   <xmp:CreatorTool>%s</xmp:CreatorTool>
   <xmp:CreateDate>%s</xmp:CreateDate>
   <xmp:ModifyDate>%s</xmp:ModifyDate>
  </rdf:Description>
  <rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/">
   <dc:format>application/pdf</dc:format>
   <dc:title><rdf:Alt><rdf:li xml:lang="x-default">%s</rdf:li></rdf:Alt></dc:title>
   <dc:creator><rdf:Seq><rdf:li>%s</rdf:li></rdf:Seq></dc:creator>
   <dc:description><rdf:Alt><rdf:li xml:lang="x-default">%s</rdf:li></rdf:Alt></dc:description>
  </rdf:Description>
 </rdf:RDF>
</x:xmpmeta>
<?xpacket end="w"?>`

	xmp_content := fmt.aprintf(xmp_template,
		producer, info.keywords,
		info.creator, iso_creation, iso_mod,
		info.title, info.author, info.subject,
	)
	defer delete(xmp_content)

	fmt.sbprintf(sb,
		"%d 0 obj\n<</Type /Metadata /Subtype /XML /Length %d>>\nstream\n%s\nendstream\nendobj\n",
		id, len(xmp_content), xmp_content,
	)
}

@(private)
pdf_date_to_iso8601 :: proc(d: string) -> string {
	s := d
	if len(s) >= 2 && s[:2] == "D:" { s = s[2:] }
	if len(s) < 8 { return "" }
	hour, min, sec := "00", "00", "00"
	if len(s) >= 14 {
		hour = s[8:10]
		min  = s[10:12]
		sec  = s[12:14]
	}
	return fmt.aprintf("%s-%s-%sT%s:%s:%sZ", s[0:4], s[4:6], s[6:8], hour, min, sec)
}
