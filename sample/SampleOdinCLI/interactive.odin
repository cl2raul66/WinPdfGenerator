package winpdfgenerator

annotation_destroy :: proc(ann: ^Annotation) {
    if ann == nil do return
    switch ann.kind {
    case .Highlight:
        if ann.highlight != nil {
            delete(ann.highlight.rects)
            free(ann.highlight)
        }
    case .Stamp:
        free(ann.stamp)
    case .Free_Text:
        free(ann.free_text)
    }
    free(ann)
}
