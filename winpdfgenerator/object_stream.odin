#+private
package winpdfgenerator

import "core:fmt"
import "core:strings"

MAX_OBJECTS_PER_OBJSTM :: 100

ObjStm_Item :: struct {
	obj_id:  int,
	content: string, // owned, delete on destroy
}

ObjStm_Builder :: struct {
	own_id: int,
	items:  [dynamic]ObjStm_Item,
}

ObjStm_Index_Entry :: struct {
	obj_id: int,
	index:  int, // posición dentro del stream (0-based)
}

ObjStm_Written :: struct {
	own_id:  int,
	offset:  i64,
	entries: []ObjStm_Index_Entry, // caller must delete
}

objstm_make :: proc(own_id: int) -> ObjStm_Builder {
	return ObjStm_Builder{own_id = own_id, items = make([dynamic]ObjStm_Item)}
}

// content se clona internamente; el caller puede liberar su copia.
objstm_add :: proc(b: ^ObjStm_Builder, obj_id: int, content: string) {
	append(&b.items, ObjStm_Item{obj_id = obj_id, content = strings.clone(content)})
}

objstm_is_full :: proc(b: ^ObjStm_Builder) -> bool {
	return len(b.items) >= MAX_OBJECTS_PER_OBJSTM
}

objstm_len :: proc(b: ^ObjStm_Builder) -> int {
	return len(b.items)
}

// Serializa y escribe el ObjStm a sb.
// Estructura interna (ISO 32000-2 §7.5.7):
//   [tabla de índices: N pares "obj_id offset_relativo"]
//   [cuerpo: valores de objetos sin obj/endobj, separados por \n]
// /First = longitud en bytes de la tabla de índices.
// Offsets del cuerpo son relativos al primer byte del cuerpo (post /First).
objstm_write :: proc(b: ^ObjStm_Builder, sb: ^strings.Builder) -> (written: ObjStm_Written, ok: bool) {
	n := len(b.items)
	if n == 0 { return {}, false }

	// ── Cuerpo: calcular offsets relativos al primer objeto ──
	body_sb  := strings.builder_make()
	rel_offs := make([]int, n)
	defer delete(rel_offs)

	for item, i in b.items {
		rel_offs[i] = strings.builder_len(body_sb)
		strings.write_string(&body_sb, item.content)
		strings.write_byte(&body_sb, '\n')
	}

	// ── Tabla de índices ──
	index_sb := strings.builder_make()
	for item, i in b.items {
		fmt.sbprintf(&index_sb, "%d %d ", item.obj_id, rel_offs[i])
	}

	first      := strings.builder_len(index_sb)
	index_str  := strings.to_string(index_sb)
	body_str   := strings.to_string(body_sb)

	// ── Combinar índice + cuerpo y comprimir ──
	full_sb := strings.builder_make()
	strings.write_string(&full_sb, index_str)
	strings.write_string(&full_sb, body_str)
	strings.builder_destroy(&index_sb)
	strings.builder_destroy(&body_sb)

	full_bytes := transmute([]byte)strings.to_string(full_sb)

	compressed, comp_ok := filter_apply_flate(full_bytes)
	use_flate  := comp_ok && compressed != nil && len(compressed) < len(full_bytes)
	payload    := use_flate ? compressed : full_bytes

	// ── Emitir objeto ──
	written.own_id = b.own_id
	written.offset = i64(strings.builder_len(sb^))

	fmt.sbprintf(sb, "%d 0 obj\n<< /Type /ObjStm /N %d /First %d", b.own_id, n, first)
	if use_flate { strings.write_string(sb, " /Filter /FlateDecode") }
	fmt.sbprintf(sb, " /Length %d >>\nstream\n", len(payload))
	strings.write_bytes(sb, payload)
	strings.write_string(sb, "\nendstream\nendobj\n")

	if use_flate { delete(compressed) }
	strings.builder_destroy(&full_sb)

	// ── Tabla de índices para el XRef Stream (tipo 2) ──
	entries := make([]ObjStm_Index_Entry, n)
	for item, i in b.items {
		entries[i] = ObjStm_Index_Entry{obj_id = item.obj_id, index = i}
	}
	written.entries = entries

	return written, true
}

objstm_destroy :: proc(b: ^ObjStm_Builder) {
	for item in b.items { delete(item.content) }
	delete(b.items)
}
