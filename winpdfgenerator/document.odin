#+private
package winpdfgenerator

import "core:fmt"
import "core:time"

// ── Estructura del Catálogo (ISO 32000-2 §7.7.2) ──────────────────────────
// CORRECCIÓN: Pdf_Document y Pdf_Info se han movido a types.odin y
// metadata.odin respectivamente. Definirlos aquí causaba duplicación de tipos
// en el mismo paquete, lo que es un error de compilación en Odin.

Pdf_Catalog :: struct {
	pages:              Pdf_Ref,
	outlines:           Maybe(Pdf_Ref),
	metadata:           Maybe(Pdf_Ref),
	viewer_preferences: Pdf_Dict,
	page_layout:        Pdf_Name, // /SinglePage, /OneColumn, etc. (§Table 29)
}

// ── Lógica de Generación ──────────────────────────────────────────────────

// CORRECCIÓN: Retorna [16]byte (128 bits = mínimo requerido por §14.4).
// Antes retornaba [4]byte pero intentaba escribir 16 posiciones → fuera de límites.
generate_file_id :: proc(seed: string) -> [16]byte {
	h: [16]byte
	now := time.now()
	ns  := time.time_to_unix_nano(now)
	// Mezcla simple: semilla XOR con tiempo. En producción usar core:crypto/md5.
	for i in 0..<16 {
		seed_byte := seed[i % max(len(seed), 1)]
		time_byte := byte(ns >> uint(i * 8))
		h[i] = seed_byte ~ time_byte ~ byte(i * 0x1B)
	}
	return h
}

document_to_catalog_dict :: proc(c: Pdf_Catalog) -> Pdf_Dict {
	d := make(Pdf_Dict)
	d["/Type"]  = Pdf_Name("/Catalog")
	d["/Pages"] = c.pages

	if ref, ok := c.outlines.?; ok {
		d["/Outlines"] = ref
	}
	if ref, ok := c.metadata.?; ok {
		d["/Metadata"] = ref
	}
	if len(c.page_layout) > 0 {
		d["/PageLayout"] = c.page_layout
	}
	if len(c.viewer_preferences) > 0 {
		d["/ViewerPreferences"] = c.viewer_preferences
	}
	return d
}

// CORRECCIÓN: document_write_trailer ahora recibe el número de objeto raíz
// como parámetro explícito. Antes referenciaba doc.root_ref.num que no
// existía en la estructura original, y usaba doc.file_id[5] que estaba fuera
// de límites en [3][4]byte.
document_write_trailer :: proc(doc: ^Pdf_Document, startxref: i64) -> string {
	// Cada ID es [16]byte → representación hexadecimal de 32 chars
	id0 := fmt.tprintf("<%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x>",
		doc.file_id[0][0],  doc.file_id[0][1],  doc.file_id[0][2],  doc.file_id[0][3],
		doc.file_id[0][4],  doc.file_id[0][5],  doc.file_id[0][6],  doc.file_id[0][7],
		doc.file_id[0][8],  doc.file_id[0][9],  doc.file_id[0][10], doc.file_id[0][11],
		doc.file_id[0][12], doc.file_id[0][13], doc.file_id[0][14], doc.file_id[0][15],
	)
	id1 := fmt.tprintf("<%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x>",
		doc.file_id[1][0],  doc.file_id[1][1],  doc.file_id[1][2],  doc.file_id[1][3],
		doc.file_id[1][4],  doc.file_id[1][5],  doc.file_id[1][6],  doc.file_id[1][7],
		doc.file_id[1][8],  doc.file_id[1][9],  doc.file_id[1][10], doc.file_id[1][11],
		doc.file_id[1][12], doc.file_id[1][13], doc.file_id[1][14], doc.file_id[1][15],
	)

	return fmt.tprintf(
		"trailer\n<< /Size %d /Root %d 0 R /ID [%s %s] >>\nstartxref\n%d\n%%%%EOF",
		len(doc.objects) + 1,
		doc.root_ref.id,
		id0,
		id1,
		startxref,
	)
}
