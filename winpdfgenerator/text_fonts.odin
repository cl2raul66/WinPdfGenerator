#+private
package winpdfgenerator

import "core:fmt"
import "core:strings"

// ── Tipos de Fuentes (ISO 32000-2 §9.6, §9.7) ─────────────────

Font_Subtype :: enum {
	Type1,
	TrueType,
	Type3,
	Type0, // Fuentes compuestas (CIDFonts, §9.7)
}

Pdf_Font :: struct {
	subtype:    Font_Subtype,
	base_font:  Pdf_Name,
	encoding:   Maybe(Pdf_Object), // Nombre (ej: /WinAnsiEncoding) o diccionario
	widths:     Maybe(Pdf_Ref),    // Referencia al array /Widths
	descriptor: Maybe(Pdf_Ref),    // FontDescriptor (obligatorio en PDF 2.0, §9.8)
	to_unicode: Maybe(Pdf_Ref),    // ToUnicode CMap para extracción de texto (§9.10)
}

// Descriptor de Fuente (§9.8) — métricas y flags globales
Pdf_Font_Descriptor :: struct {
	font_name:     Pdf_Name,
	flags:         u32,           // §Table 121 (FixedPitch, Serif, Symbolic, etc.)
	font_bbox:     Rect,
	italic_angle:  f32,
	ascent:        f32,
	descent:       f32,
	cap_height:    f32,
	stem_v:        f32,
	missing_width: Maybe(f32),
	font_file:     Maybe(Pdf_Ref), // Stream embebido (.ttf, .otf, etc.)
}

// ── Operadores de Estado de Texto (§9.3) ──────────────────────

write_text_font :: proc(sb: ^strings.Builder, alias: Pdf_Name, size: f32) {
	fmt.sbprintf(sb, "%s %.4f Tf\n", alias, size)
}

write_char_spacing :: proc(sb: ^strings.Builder, char_space: f32) {
	fmt.sbprintf(sb, "%.4f Tc\n", char_space)
}

write_word_spacing :: proc(sb: ^strings.Builder, word_space: f32) {
	fmt.sbprintf(sb, "%.4f Tw\n", word_space)
}

write_text_render_mode :: proc(sb: ^strings.Builder, mode: int) {
	// 0=Fill, 1=Stroke, 2=FillThenStroke, 3=Invisible, etc. (§Table 106)
	fmt.sbprintf(sb, "%d Tr\n", mode)
}

// Escala horizontal del texto (§9.3.3)
write_text_scale :: proc(sb: ^strings.Builder, scale: f32) {
	fmt.sbprintf(sb, "%.4f Tz\n", scale)
}

// Leading entre líneas (§9.3.5)
write_text_leading :: proc(sb: ^strings.Builder, leading: f32) {
	fmt.sbprintf(sb, "%.4f TL\n", leading)
}

// ── Operadores de Posicionamiento y Pintado (§9.4) ────────────

write_text_begin :: proc(sb: ^strings.Builder) {
	strings.write_string(sb, "BT\n")
}

write_text_end :: proc(sb: ^strings.Builder) {
	strings.write_string(sb, "ET\n")
}

write_text_move :: proc(sb: ^strings.Builder, tx, ty: f32) {
	fmt.sbprintf(sb, "%.4f %.4f Td\n", tx, ty)
}

// Posicionamiento absoluto vía matriz (Tm)
write_text_matrix :: proc(sb: ^strings.Builder, a, b, c, d, e, f: f32) {
	fmt.sbprintf(sb, "%.4f %.4f %.4f %.4f %.4f %.4f Tm\n", a, b, c, d, e, f)
}

write_text_show :: proc(sb: ^strings.Builder, text: string) {
	strings.write_string(sb, "(")
	pdf_escape_string(sb, text)
	strings.write_string(sb, ") Tj\n")
}

// Operador TJ: permite kerning y ajustes de posición individuales (§9.4.3)
Text_Item :: union {
	string,
	f32,
}

write_text_show_kerning :: proc(sb: ^strings.Builder, items: []Text_Item) {
	strings.write_string(sb, "[")
	for item in items {
		switch v in item {
		case string:
			strings.write_string(sb, "(")
			pdf_escape_string(sb, v)
			strings.write_string(sb, ") ")
		case f32:
			fmt.sbprintf(sb, "%.4f ", v)
		}
	}
	strings.write_string(sb, "] TJ\n")
}

// ── Lógica del Motor ──────────────────────────────────────────

// Escapado obligatorio para cadenas literales PDF (ISO 32000-2 §7.3.4.2)
pdf_escape_string :: proc(sb: ^strings.Builder, s: string) {
	for i in 0..<len(s) {
		b := s[i]
		switch b {
		case '(':  strings.write_string(sb, "\\(")
		case ')':  strings.write_string(sb, "\\)")
		case '\\': strings.write_string(sb, "\\\\")
		case '\r': strings.write_string(sb, "\\r")
		case '\n': strings.write_string(sb, "\\n")
		case:      strings.write_byte(sb, b)
		}
	}
}

font_to_pdf_dict :: proc(f: Pdf_Font) -> Pdf_Dict {
	d := make(Pdf_Dict)
	d["/Type"]     = Pdf_Name("/Font")
	d["/Subtype"]  = font_subtype_to_name(f.subtype)
	d["/BaseFont"] = f.base_font
	if enc,  ok := f.encoding.?;   ok { d["/Encoding"]      = enc }
	if w,    ok := f.widths.?;     ok { d["/Widths"]        = w   }
	if desc, ok := f.descriptor.?; ok { d["/FontDescriptor"] = desc }
	if uni,  ok := f.to_unicode.?; ok { d["/ToUnicode"]     = uni  }
	return d
}

@(private)
font_subtype_to_name :: proc(s: Font_Subtype) -> Pdf_Name {
	switch s {
	case .Type1:    return Pdf_Name("/Type1")
	case .TrueType: return Pdf_Name("/TrueType")
	case .Type3:    return Pdf_Name("/Type3")
	case .Type0:    return Pdf_Name("/Type0")
	}
	return Pdf_Name("/Type1")
}

// API de alto nivel para escribir texto en un content stream
write_text_ops :: proc(sb: ^strings.Builder, obj: ^Pdf_Page_Text_Object, font_alias: Pdf_Name) {
	write_text_begin(sb)
	write_text_font(sb, font_alias, obj.font_size)
	write_fill_rgb(sb, obj.color) // Definido en color.odin
	write_text_move(sb, obj.x, obj.y)
	write_text_show(sb, obj.text)
	write_text_end(sb)
}
