package winpdfgenerator

import "core:fmt"
import "core:os"
import "core:strings"

Font_Entry :: struct {
    alias:     string,
    base_font: string,
}

page_destroy :: proc(page: ^Pdf_Page) {
    for item in page.items {
        switch item.kind {
        case .Text:  free(item.text)
        case .Path:  delete(item.path.commands); free(item.path)
        case .Image: free(item.image)
        }
    }
    delete(page.items)
    for ann in page.annotations  { annotation_destroy(ann) }
    delete(page.annotations)
    for l in page.links          { free(l) }; delete(page.links)
    for l in page.goto_links     { free(l) }; delete(page.goto_links)
    for w in page.form_widgets   { free(w) }; delete(page.form_widgets)
    free(page)
}

serialize_document :: proc(doc: ^Pdf_Document, filename: string) -> bool {
    h, err := os.open(filename, os.O_WRONLY | os.O_CREATE | os.O_TRUNC)
    if err != 0 do return false
    defer os.close(h)

    n := len(doc.pages)
    total := 2 + n * 2
    xrefs := make([]XRef_Entry, total)
    defer delete(xrefs)

    write_header(h)

    xrefs[0] = {offset = tell(h), in_use = true}
    fmt.fprintf(h, "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")

    xrefs[1] = {offset = tell(h), in_use = true}
    {
        sb := strings.builder_make(); defer strings.builder_destroy(&sb)
        fmt.sbprintf(&sb, "2 0 obj\n<< /Type /Pages /Kids [")
        for i in 0..<n { fmt.sbprintf(&sb, "%d 0 R ", 3 + i * 2) }
        fmt.sbprintf(&sb, "] /Count %d >>\nendobj\n", n)
        fmt.fprintf(h, "%s", strings.to_string(sb))
    }

    for i in 0..<n {
        page    := doc.pages[i]
        page_id := 3 + i * 2
        cont_id := 3 + i * 2 + 1

        fonts, content := build_page_content(page)
        defer {
            delete(content)
            for f in fonts { delete(f.alias); delete(f.base_font) }
            delete(fonts)
        }

        xrefs[2 + i * 2] = {offset = tell(h), in_use = true}
        {
            sb := strings.builder_make(); defer strings.builder_destroy(&sb)
            fmt.sbprintf(&sb, "%d 0 obj\n<<", page_id)
            fmt.sbprintf(&sb, " /Type /Page /Parent 2 0 R")
            fmt.sbprintf(&sb, " /MediaBox [0 0 %d %d]", page.info.width_pts, page.info.height_pts)
            fmt.sbprintf(&sb, " /Resources <<")
            if len(fonts) > 0 {
                fmt.sbprintf(&sb, " /Font <<")
                for f in fonts {
                    fmt.sbprintf(&sb,
                        " /%s << /Type /Font /Subtype /Type1 /BaseFont /%s >>",
                        f.alias, f.base_font)
                }
                fmt.sbprintf(&sb, " >>")
            }
            fmt.sbprintf(&sb, " >> /Contents %d 0 R >>\nendobj\n", cont_id)
            fmt.fprintf(h, "%s", strings.to_string(sb))
        }

        xrefs[2 + i * 2 + 1] = {offset = tell(h), in_use = true}
        fmt.fprintf(h, "%d 0 obj\n<< /Length %d >>\nstream\n%s\nendstream\nendobj\n",
            cont_id, len(content), content)
    }

    xref_pos := tell(h)
    write_xref(h, xrefs)
    write_trailer(h, total + 1, 1, xref_pos)
    return true
}

@(private)
tell :: proc(h: ^os.File) -> i64 {
    off, _ := os.seek(h, 0, .Current)
    return off
}

@(private)
build_page_content :: proc(page: ^Pdf_Page) -> ([]Font_Entry, string) {
    base_to_alias := make(map[string]string)
    n_fonts := 0
    for item in page.items {
        if item.kind == .Text {
            base := canonical_font(item.text.font_name)
            if base not_in base_to_alias {
                n_fonts += 1
                base_to_alias[base] = fmt.aprintf("F%d", n_fonts)
            }
        }
    }

    sb := strings.builder_make()
    for item in page.items {
        switch item.kind {
        case .Text:  write_text_ops(&sb, item.text, base_to_alias[canonical_font(item.text.font_name)])
        case .Path:  write_path_ops(&sb, item.path)
        case .Image: write_image_ops(&sb, item.image)
        }
    }
    content := strings.clone(strings.to_string(sb))
    strings.builder_destroy(&sb)

    font_entries := make([dynamic]Font_Entry)
    for base, alias in base_to_alias {
        append(&font_entries, Font_Entry{
            alias     = strings.clone(alias),
            base_font = strings.clone(base),
        })
        delete(alias)
    }
    delete(base_to_alias)

    return font_entries[:], content
}

@(private)
canonical_font :: proc(name: string) -> string {
    switch name {
    case "Helvetica", "helvetica", "sans", "Arial":  return "Helvetica"
    case "Helvetica-Bold", "bold":                   return "Helvetica-Bold"
    case "Helvetica-Oblique", "italic":              return "Helvetica-Oblique"
    case "Times-Roman", "Times", "times", "serif":   return "Times-Roman"
    case "Times-Bold":                               return "Times-Bold"
    case "Courier", "courier", "mono":               return "Courier"
    case "Courier-Bold":                             return "Courier-Bold"
    case:                                            return name
    }
}
