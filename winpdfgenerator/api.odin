package winpdfgenerator

import "core:os"

@(export)
generate_blank_pdf :: proc(filename: cstring) {
	filename_str := string(filename)
	h, err := os.open(filename_str, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
	if err != 0 {
		return
	}
	defer os.close(h)

	xref_entries: [3]XRef_Entry

	write_header(h)

	xref_entries[0].offset = write_obj_header(h, 1, 0)
	xref_entries[0].gen = 0
	xref_entries[0].in_use = true
	write_catalog(h, 2)

	xref_entries[1].offset = write_obj_header(h, 2, 0)
	xref_entries[1].gen = 0
	xref_entries[1].in_use = true
	write_page_tree(h, []int{3})

	xref_entries[2].offset = write_obj_header(h, 3, 0)
	xref_entries[2].gen = 0
	xref_entries[2].in_use = true
	write_page(h, 2)

	xref_pos := write_xref(h, xref_entries[:])

	write_trailer(h, 4, 1, xref_pos)
}
