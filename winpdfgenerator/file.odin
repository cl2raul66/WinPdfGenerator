package winpdfgenerator

import "core:fmt"
import "core:os"

// Escribe la cabecera PDF 2.0 y caracteres binarios para compatibilidad [14, 15]
write_header :: proc(h: ^os.File) {
	fmt.fprintf(h, "%%PDF-2.0\n")
	fmt.fprintf(h, "%%\u00E2\u00E3\u00CF\u00D3\n")
}

// Genera la tabla de referencias cruzadas al final del fichero [12, 16]
write_xref :: proc(h: ^os.File, entries: []XRef_Entry) -> i64 {
	start_offset, _ := os.seek(h, 0, .Current)
	fmt.fprintf(h, "xref\n0 %d\n", len(entries) + 1)

	// Entrada especial para el objeto 0 [16, 17]
	fmt.fprintf(h, "0000000000 65535 f \r\n")

	for entry in entries {
		fmt.fprintf(h, "%010d %05d n \r\n", entry.offset, entry.gen)
	}
	return start_offset
}

// Escribe el trailer que apunta al Catálogo (Root) [18-20]
write_trailer :: proc(h: ^os.File, size: int, root_id: int, xref_offset: i64) {
	fmt.fprintf(h, "trailer\n<< /Size %d /Root %d 0 R >>\n", size + 1, root_id)
	fmt.fprintf(h, "startxref\n%d\n%%%%EOF\n", xref_offset)
}
