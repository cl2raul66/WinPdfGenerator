#+private
package winpdfgenerator

import "core:fmt"
import "core:strings"
import "core:time"

// ── Tipos de Firma (ISO 32000-2 §12.8.3) ──────────────────────

Sig_Sub_Filter :: enum {
	PKCS7_Detached,
	CAdES_Detached,
	RFC3161,
}

MDP_Permission :: enum i64 {
	No_Changes_Permitted = 1,
	Form_Fill_Signing = 2,
	Annot_And_Form_Signing = 3,
}

Sig_Field_Lock :: struct {
	action: Pdf_Name,
	fields: [dynamic]string,
}

Sig_Seed_Value :: struct {
	reasons: [dynamic]string,
	digest_methods: [dynamic]Pdf_Name,
	sub_filters: [dynamic]Pdf_Name,
	legal_attest: [dynamic]string,
	lock_document: bool,
}

Sig_Field :: struct {
	page: int,
	rect: Rect,
	sub_filter: Sig_Sub_Filter,
	reason: string,
	location: string,
	contact: string,
	reserved_size: int,
	mdp_perm: Maybe(MDP_Permission),
	lock: Maybe(Sig_Field_Lock),
	seed:  Maybe(Sig_Seed_Value),
}

// Posiciones en el buffer PDF para el parcheo posterior de la firma
Sig_Placeholder :: struct {
	byte_range_offset: int,
	contents_offset: int,
	reserved_size: int,
}

// IDs de los objetos PDF que componen un campo de firma.
Sig_Object_Ids :: struct {
	sig_value_id:  int, // Objeto /Sig (contiene ByteRange y Contents)
	widget_id:     int, // Anotación /Widget (caja visual del campo)
	acroform_id:   int, // /AcroForm (raíz del formulario)
}

// ── Helpers ───────────────────────────────────────────────────

@(private)
sig_sub_filter_name :: proc(sf: Sig_Sub_Filter) -> string {
	switch sf {
		case .PKCS7_Detached: return "adbe.pkcs7.detached"
		case .CAdES_Detached: return "ETSI.CAdES.detached"
		case .RFC3161: return "ETSI.RFC3161"
	}
	return "adbe.pkcs7.detached"
}

@(private)
current_pdf_date :: proc() -> string {
	now := time.now()
	y, m, d := time.date(now)
	hh, mm, ss := time.clock_from_time(now)
	return fmt.aprintf("D:%04d%02d%02d%02d%02d%02d+00'00'", y, int(m), d, hh, mm, ss)
}

// ── Fase 1: Escritura del objeto /Sig con placeholders ────────
//
// Emite el objeto de firma con ByteRange y Contents como placeholders
// de ancho fijo. Los offsets devueltos en Sig_Placeholder son absolutos
// respecto al inicio del builder en el momento de la llamada.
//
// Flujo completo de firma:
//   1. serialize_document escribe el PDF completo con los placeholders.
//   2. El caller calcula ByteRange (todo excepto el hex de Contents).
//   3. patch_signature rellena ByteRange y Contents en el buffer en memoria.
//   4. El caller firma los bytes indicados por ByteRange con su clave privada
//      y llama patch_signature por segunda vez con la firma DER real.

write_sig_value_object :: proc(sb: ^strings.Builder, id: int, sf: ^Sig_Field, base_offset: int) -> Sig_Placeholder {
	reserved := sf.reserved_size > 0 ? sf.reserved_size : 8192

	start_len := strings.builder_len(sb^)

	fmt.sbprintf(sb, "%d 0 obj\n<<\n", id)
	fmt.sbprintf(sb, "  /Type /Sig\n")
	fmt.sbprintf(sb, "  /Filter /Adobe.PPKLite\n")
	fmt.sbprintf(sb, "  /SubFilter /%s\n", sig_sub_filter_name(sf.sub_filter))

	date_str := current_pdf_date()
	defer delete(date_str)
	fmt.sbprintf(sb, "  /M (%s)\n", date_str)

	if sf.reason != "" { fmt.sbprintf(sb, "  /Reason (%s)\n", sf.reason) }
	if sf.location != "" { fmt.sbprintf(sb, "  /Location (%s)\n", sf.location) }
	if sf.contact != "" { fmt.sbprintf(sb, "  /ContactInfo (%s)\n", sf.contact) }

	if perm, ok := sf.mdp_perm.?; ok {
		fmt.sbprintf(sb,
			"  /Reference [\n    << /Type /SigRef /TransformMethod /DocMDP /TransformParams << /Type /TransformParams /P %d /V /1.2 >> >>\n  ]\n",
			i64(perm),
		)
	}

	// ByteRange placeholder: 4 enteros de 10 dígitos
	byte_range_offset := base_offset + strings.builder_len(sb^) - start_len + len("  /ByteRange ")
	fmt.sbprintf(sb, "  /ByteRange [%010d %010d %010d %010d]\n", 0, 0, 0, 0)

	// Contents placeholder: hex de 'reserved' bytes (2 hex chars por byte)
	contents_offset := base_offset + strings.builder_len(sb^) - start_len + len("  /Contents <")
	fmt.sbprintf(sb, "  /Contents <")
	for _ in 0..<reserved { strings.write_string(sb, "00") }
	strings.write_string(sb, ">\n>>\nendobj\n")

	return Sig_Placeholder{
		byte_range_offset = byte_range_offset,
		contents_offset   = contents_offset,
		reserved_size     = reserved,
	}
}

// ── Widget de anotación /Widget (§12.5.6.19) ─────────────────
// Representa la caja visual del campo de firma en la página.
// rect_str: "[llx lly urx ury]" ya formateado.

write_sig_widget :: proc(sb: ^strings.Builder, widget_id, sig_value_id, page_id: int, rect: Rect,) {
	fmt.sbprintf(sb,
		"%d 0 obj\n<< /Type /Annot /Subtype /Widget /FT /Sig /T (Signature1) /V %d 0 R /Rect [%.4f %.4f %.4f %.4f] /P %d 0 R /F 4 >>\nendobj\n",
		widget_id, sig_value_id,
		rect.llx, rect.lly, rect.urx, rect.ury,
		page_id)
}

// ── AcroForm (§12.7.3) ────────────────────────────────────────
// Raíz del formulario interactivo; referencia todos los widgets de firma.
// widget_ids: slice de IDs de todos los widgets del documento.

write_acroform :: proc(sb: ^strings.Builder, acroform_id: int, widget_ids: []int,) {
	fmt.sbprintf(sb, "%d 0 obj\n<< /Fields [", acroform_id)
	for wid in widget_ids {
		fmt.sbprintf(sb, "%d 0 R ", wid)
	}
	strings.write_string(sb, "] /SigFlags 3 >>\nendobj\n")
}

// ── Fase 2: Parcheo del buffer PDF en memoria ─────────────────
//
// Rellena ByteRange y Contents en el slice mutable del PDF completo.
// Llamar dos veces:
//   1ª llamada: signature_data = nil  → solo parchea ByteRange.
//   2ª llamada: signature_data = firma DER → parchea Contents.

patch_signature :: proc(pdf_buf: []byte, ph: Sig_Placeholder, signature_data: []byte) -> bool {
	file_size := len(pdf_buf)

	pos1 := 0
	len1 := ph.contents_offset - 1 // bytes antes de '<'
	pos2 := ph.contents_offset + ph.reserved_size * 2 + 1 // después de '>'
	len2 := file_size - pos2

	// 1. Parchear ByteRange
	byte_range_str := fmt.aprintf("[%010d %010d %010d %010d]", pos1, len1, pos2, len2)
	defer delete(byte_range_str)
	copy(pdf_buf[ph.byte_range_offset:], transmute([]byte)byte_range_str)

	// 2. Parchear Contents si se proporcionó la firma
	if signature_data != nil {
		if len(signature_data) > ph.reserved_size { return false }

		sig_hex_sb := strings.builder_make()
		defer strings.builder_destroy(&sig_hex_sb)
		for b in signature_data { fmt.sbprintf(&sig_hex_sb, "%02x", b) }
		sig_hex := strings.to_string(sig_hex_sb)
		copy(pdf_buf[ph.contents_offset:], transmute([]byte)sig_hex)
	}

	return true
}
