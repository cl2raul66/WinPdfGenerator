package pdf_cli

import "core:fmt"

foreign import winpdfgenerator "../../bin/WinPdfGenerator.lib"

foreign winpdfgenerator {
	generate_blank_pdf :: proc(filename: cstring) ---
}

main :: proc() {
	generate_blank_pdf("bin/output_odin.pdf")
	fmt.println("PDF generado: bin/output_odin.pdf")
}
