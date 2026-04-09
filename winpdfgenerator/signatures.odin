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
	reasons, legal_attest: [dynamic]string,
	digest_methods, sub_filters: [dynamic]Pdf_Name,
	lock_document: bool,
}

Sig_Field :: struct {
	page, reserved_size: int,
	rect: Rect,
	sub_filter: Sig_Sub_Filter,
	reason, location, contact: string,
	mdp_perm: Maybe(MDP_Permission),
	lock: Maybe(Sig_Field_Lock),
	seed:  Maybe(Sig_Seed_Value),
}

Sig_Placeholder :: struct {
	byte_range_offset, contents_offset, reserved_size: int,
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

// ── Fase 1: Objeto /Sig con placeholders ─────────────────────

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

	byte_range_offset := base_offset + strings.builder_len(sb^) - start_len + len("  /ByteRange ")
	fmt.sbprintf(sb, "  /ByteRange [%010d %010d %010d %010d]\n", 0, 0, 0, 0)

	contents_offset := base_offset + strings.builder_len(sb^) - start_len + len("  /Contents <")
	fmt.sbprintf(sb, "  /Contents <")
	for _ in 0 ..< reserved { strings.write_string(sb, "00") }
	strings.write_string(sb, ">\n>>\nendobj\n")

	return Sig_Placeholder{
		byte_range_offset = byte_range_offset,
		contents_offset = contents_offset,
		reserved_size = reserved,
	}
}

// ── XObject de apariencia vacío para el widget (ISO 32000-2 §12.5.5) ─────
// En PDF 2.0, /AP es obligatorio en toda anotación visible (Rect con
// dimensiones > 0). Se emite un Form XObject vacío como apariencia normal.

write_sig_appearance_xobject :: proc(sb: ^strings.Builder, ap_id: int, rect: Rect) {
	w := rect.urx - rect.llx
	h := rect.ury - rect.lly
	fmt.sbprintf(sb, "%d 0 obj\n<< /Type /XObject /Subtype /Form /BBox [0 0 %.4f %.4f] /Length 0 >>\nstream\n\nendstream\nendobj\n", ap_id, w, h)
}

// ── Widget /Widget (§12.5.6.19) ──────────────────────────────
// field_idx (0-based): usado para generar /T único ("Signature1", "Signature2"…).
// ap_id > 0: añade /AP obligatorio para campos con Rect de dimensiones > 0.

write_sig_widget :: proc(sb: ^strings.Builder, widget_id, sig_value_id, page_id, field_idx: int, rect: Rect, ap_id: int) {
	fmt.sbprintf(sb,
		"%d 0 obj\n<< /Type /Annot /Subtype /Widget /FT /Sig /T (Signature%d) /V %d 0 R /Rect [%.4f %.4f %.4f %.4f] /P %d 0 R /F 4", widget_id, field_idx + 1, sig_value_id, rect.llx, rect.lly, rect.urx, rect.ury,
		page_id)

	if ap_id > 0 {
		fmt.sbprintf(sb, " /AP << /N %d 0 R >>", ap_id)
	}

	strings.write_string(sb, " >>\nendobj\n")
}

// ── Fase 2: Parcheo del buffer PDF en memoria ─────────────────

patch_signature :: proc(pdf_buf: []byte, ph: Sig_Placeholder, signature_data: []byte) -> bool {
	file_size := len(pdf_buf)

	pos1 := 0
	len1 := ph.contents_offset - 1
	pos2 := ph.contents_offset + ph.reserved_size * 2 + 1
	len2 := file_size - pos2

	byte_range_str := fmt.aprintf("[%010d %010d %010d %010d]", pos1, len1, pos2, len2)
	defer delete(byte_range_str)
	copy(pdf_buf[ph.byte_range_offset:], transmute([]byte)byte_range_str)

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
