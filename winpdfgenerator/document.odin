package winpdfgenerator

import "core:fmt"
import "core:os"

// Escribe un objeto indirecto genérico [24]
write_obj_header :: proc(h: ^os.File, id: int, gen: int) -> i64 {
	offset, _ := os.seek(h, 0, .Current)
	fmt.fprintf(h, "%d %d obj\n", id, gen)
	return offset
}

// Crea el Diccionario de Catálogo (Root) [5, 22, 25]
write_catalog :: proc(h: ^os.File, pages_id: int) {
	fmt.fprintf(h, "<< /Type /Catalog /Pages %d 0 R >>\nendobj\n", pages_id)
}

// Crea el nodo raíz del Árbol de Páginas [23, 25, 26]
write_page_tree :: proc(h: ^os.File, page_ids: []int) {
	fmt.fprintf(h, "<< /Type /Pages /Kids [")
	for id in page_ids {
		fmt.fprintf(h, "%d 0 R ", id)
	}
	fmt.fprintf(h, "] /Count %d >>\nendobj\n", len(page_ids))
}

// Crea un objeto de página individual con su MediaBox (tamaño carta por defecto) [25, 27, 28]
write_page :: proc(h: ^os.File, parent_id: int) {
	fmt.fprintf(
		h,
		"<< /Type /Page /Parent %d 0 R /MediaBox [0 0 612 792] /Resources << >> >>\nendobj\n",
		parent_id,
	)
}
