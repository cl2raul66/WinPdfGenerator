package main

import "core:fmt"
import "core:os"

@(private)
leer_opcion :: proc() -> int {
	data: [16]byte
	n, _ := os.read(os.stdin, data[:])
	if n <= 0 do return -1

	num := 0
	started := false
	for i := 0; i < n; i += 1 {
		c := data[i]
		if c >= '0' && c <= '9' {
			num = num * 10 + int(c - '0')
			started = true
		} else if started {
			break
		}
	}
	return num
}

@(private)
generar_documento_en_blanco :: proc(filename: cstring) -> bool {
	doc := pdf_document_create()
	defer pdf_document_close(doc)

	b := page_info_builder_create(1, 595, 842)
	info := page_info_builder_build(b)
	defer page_info_free(info)

	page := pdf_document_start_page(doc, info)
	pdf_document_finish_page(doc, page)

	return bool(pdf_document_write_to_file(doc, filename))
}

main :: proc() {
	for {
		fmt.println("=================================")
		fmt.println("  Generador de PDF - Menu (DLL)")
		fmt.println("=================================")
		fmt.println("1. Documento en blanco (A4 Vertical)")
		fmt.println("0. Salir")
		fmt.println()
		fmt.print("Seleccione opcion: ")

		opcion := leer_opcion()
		fmt.println()

		switch opcion {
		case 1:
			filename := cstring("SampleOdin - Blank Document.pdf")
			if generar_documento_en_blanco(filename) {
				fmt.println("PDF generado exitosamente: SampleOdin - Blank Document.pdf")
			} else {
				fmt.println("Error al generar el PDF")
			}
		case 0:
			fmt.println("Saliendo...")
			return
		case:
			fmt.println("Opcion invalida. Intente de nuevo.")
		}
		fmt.println()
	}
}
