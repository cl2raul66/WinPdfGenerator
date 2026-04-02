#+private
package winpdfgenerator

import "core:fmt"
import "core:strings"

// ── Tipos de Firma (ISO 32000-2 §12.8.3) ──────────────────────

Sig_Sub_Filter :: enum {
	PKCS7_Detached,
	CAdES_Detached,
	RFC3161,
}

MDP_Permission :: enum i64 {
	No_Changes_Permitted   = 1,
	Form_Fill_Signing      = 2,
	Annot_And_Form_Signing = 3,
}

Sig_Field_Lock :: struct {
	action: Pdf_Name,
	fields: [dynamic]string,
}

Sig_Seed_Value :: struct {
	reasons:        [dynamic]string,
	digest_methods: [dynamic]Pdf_Name,
	sub_filters:    [dynamic]Pdf_Name,
	legal_attest:   [dynamic]string,
	lock_document:  bool,
}

Sig_Field :: struct {
	page:          int,
	rect:          Rect,
	sub_filter:    Sig_Sub_Filter,
	reason:        string,
	location:      string,
	contact:       string,
	reserved_size: int,
	mdp_perm:      Maybe(MDP_Permission),
	lock:          Maybe(Sig_Field_Lock),
	seed:          Maybe(Sig_Seed_Value),
}

// Posiciones en el buffer PDF para el parcheo posterior de la firma
Sig_Placeholder :: struct {
	byte_range_offset: int, // Offset del valor de ByteRange en el buffer
	contents_offset:   int, // Offset del hex de Contents en el buffer
	reserved_size:     int, // Bytes reservados para la firma
}

// CORRECCIÓN: os.Handle y os.SEEK_* no disponibles en esta versión de Odin.
// Se adopta arquitectura basada en buffer de bytes en memoria:
// write_sig_value_object escribe a ^strings.Builder y retorna offsets.
// patch_signature trabaja sobre el []byte del PDF completo.

@(private)
sig_sub_filter_name :: proc(sf: Sig_Sub_Filter) -> string {
	switch sf {
	case .PKCS7_Detached: return "adbe.pkcs7.detached"
	case .CAdES_Detached: return "ETSI.CAdES.detached"
	case .RFC3161:        return "ETSI.RFC3161"
	}
	return "adbe.pkcs7.detached"
}

// Fase 1: Escribe el objeto firma con placeholders al builder.
// Los offsets en Sig_Placeholder son relativos al inicio del builder
// en el momento de la llamada (base_offset debe sumarse externamente).
write_sig_value_object :: proc(sb: ^strings.Builder, id: int, sf: ^Sig_Field, base_offset: int) -> Sig_Placeholder {
	reserved := sf.reserved_size > 0 ? sf.reserved_size : 8192

	start_len := strings.builder_len(sb^)

	fmt.sbprintf(sb, "%d 0 obj\n<<\n", id)
	fmt.sbprintf(sb, "  /Type /Sig\n")
	fmt.sbprintf(sb, "  /Filter /Adobe.PPKLite\n")
	fmt.sbprintf(sb, "  /SubFilter /%s\n", sig_sub_filter_name(sf.sub_filter))

	if sf.reason   != "" { fmt.sbprintf(sb, "  /Reason (%s)\n",      sf.reason) }
	if sf.location != "" { fmt.sbprintf(sb, "  /Location (%s)\n",    sf.location) }
	if sf.contact  != "" { fmt.sbprintf(sb, "  /ContactInfo (%s)\n", sf.contact) }
	fmt.sbprintf(sb, "  /M (%s)\n", pdf_date_now())

	if perm, ok := sf.mdp_perm.?; ok {
		fmt.sbprintf(sb,
			"  /Reference [\n    << /Type /SigRef /TransformMethod /DocMDP /TransformParams << /Type /TransformParams /P %d /V /1.2 >> >>\n  ]\n",
			i64(perm),
		)
	}

	// Offset de ByteRange relativo al inicio del documento
	byte_range_offset := base_offset + strings.builder_len(sb^) - start_len + len("  /ByteRange ")
	// Placeholder con 4 enteros de 10 dígitos: [0000000000 0000000000 0000000000 0000000000]
	fmt.sbprintf(sb, "  /ByteRange [%010d %010d %010d %010d]\n", 0, 0, 0, 0)

	// Offset de Contents (hex de la firma)
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

// Fase 2: Parchea el buffer del PDF en memoria con el ByteRange real y la firma DER.
// 'pdf_buf' es el slice mutable del PDF completo ya serializado.
patch_signature :: proc(pdf_buf: []byte, ph: Sig_Placeholder, signature_data: []byte) -> bool {
	if len(signature_data) > ph.reserved_size { return false }

	file_size := len(pdf_buf)

	pos1 := 0
	len1 := ph.contents_offset - 1
	pos2 := ph.contents_offset + ph.reserved_size * 2 + 1
	len2 := file_size - pos2

	byte_range_str := fmt.aprintf("[%010d %010d %010d %010d]", pos1, len1, pos2, len2)
	defer delete(byte_range_str)

	// 1. Escribir ByteRange real en su posición
	brs := transmute([]byte)byte_range_str
	copy(pdf_buf[ph.byte_range_offset:], brs)

	// 2. Escribir firma en hex en su posición
	sig_hex_sb := strings.builder_make()
	defer strings.builder_destroy(&sig_hex_sb)
	for b in signature_data { fmt.sbprintf(&sig_hex_sb, "%02x", b) }
	sig_hex := strings.to_string(sig_hex_sb)
	copy(pdf_buf[ph.contents_offset:], transmute([]byte)sig_hex)

	return true
}
