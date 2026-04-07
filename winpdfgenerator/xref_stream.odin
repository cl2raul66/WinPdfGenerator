#+private
package winpdfgenerator

import "core:fmt"
import "core:strings"

// ── Tipos de entrada del Cross-Reference Stream (ISO 32000-2 §7.5.8.3) ──

Xref_Record_Kind :: enum u8 {
	Free       = 0, // objeto libre        — campo-a: siguiente libre, campo-b: gen
	Direct     = 1, // objeto sin comprimir — campo-a: byte offset,    campo-b: gen
	Compressed = 2, // objeto en ObjStm    — campo-a: obj_id del ObjStm, campo-b: índice
}

Xref_Record :: struct {
	kind: Xref_Record_Kind,
	a:    i64, // Direct: offset en bytes;   Compressed: obj_id del ObjStm
	b:    int, // Direct: número de gen (0); Compressed: índice en el ObjStm
}

// ── Helpers internos ──────────────────────────────────────────

// Bytes mínimos necesarios para representar v en big-endian (mínimo 1).
@(private)
xref_min_bytes :: proc(v: i64) -> int {
	if v <= 0xFF             { return 1 }
	if v <= 0xFFFF           { return 2 }
	if v <= 0xFFFFFF         { return 3 }
	if v <= 0xFFFFFFFF       { return 4 }
	if v <= 0xFFFFFFFFFF     { return 5 }
	return 6
}

// Escribe v en big-endian con exactamente n bytes al buffer.
@(private)
xref_write_be :: proc(buf: ^[dynamic]byte, v: i64, n: int) {
	for i := n - 1; i >= 0; i -= 1 {
		append(buf, byte(v >> uint(i * 8)))
	}
}

// ── Escritura del Cross-Reference Stream ─────────────────────
//
// Reemplaza la tabla xref tradicional y el bloque trailer.
// El diccionario del stream integra /Size, /Root e /ID (ISO 32000-2 §7.5.8.2).
//
// records[0]        = entrada libre cabecera (objeto 0)
// records[obj_id]   = entrada del objeto obj_id
// records[xref_id]  = entrada del propio stream (tipo Direct, ya rellenada por el caller)
//
// El caller debe escribir "startxref\n<offset>\n%%EOF" DESPUÉS de esta proc.
write_xref_stream :: proc(
	sb:      ^strings.Builder,
	xref_id: int,
	records: []Xref_Record, // tamaño = total_ids + 1 (índice = obj_id)
	root_id: int,
	file_id: [2][16]byte,
) {
	n := len(records) // incluye el objeto 0

	// Calcular anchos de campo /W [w1 w2 w3]
	max_a: i64 = 0
	max_b: i64 = 0
	for rec in records {
		if rec.a > max_a            { max_a = rec.a }
		if i64(rec.b) > max_b      { max_b = i64(rec.b) }
	}
	w1 := 1
	w2 := xref_min_bytes(max_a)
	w3 := xref_min_bytes(max_b)

	// Construir datos binarios crudos
	raw := make([dynamic]byte)
	defer delete(raw)

	for rec in records {
		append(&raw, u8(rec.kind))
		xref_write_be(&raw, rec.a,      w2)
		xref_write_be(&raw, i64(rec.b), w3)
	}

	raw_slice := raw[:]
	compressed, comp_ok := filter_apply_flate(raw_slice)
	use_flate  := comp_ok && compressed != nil && len(compressed) < len(raw_slice)
	payload    := use_flate ? compressed : raw_slice

	// Emitir el objeto stream
	fmt.sbprintf(sb, "%d 0 obj\n<<\n", xref_id)
	fmt.sbprintf(sb, "  /Type /XRef\n")
	fmt.sbprintf(sb, "  /Size %d\n", n)
	fmt.sbprintf(sb, "  /W [%d %d %d]\n", w1, w2, w3)
	fmt.sbprintf(sb, "  /Root %d 0 R\n", root_id)
	strings.write_string(sb, "  /ID [<")
	for b in file_id[0] { fmt.sbprintf(sb, "%02x", b) }
	strings.write_string(sb, "> <")
	for b in file_id[1] { fmt.sbprintf(sb, "%02x", b) }
	strings.write_string(sb, ">]\n")
	if use_flate { strings.write_string(sb, "  /Filter /FlateDecode\n") }
	fmt.sbprintf(sb, "  /Length %d\n", len(payload))
	strings.write_string(sb, ">>\nstream\n")
	strings.write_bytes(sb, payload)
	strings.write_string(sb, "\nendstream\nendobj\n")

	if use_flate { delete(compressed) }
}
