#pragma once

extern "C" {
    void* pdf_document_create();
    int pdf_document_write_to_file(void* doc, const char* filename);
    void pdf_document_close(void* doc);
    void* page_info_builder_create(int page_num, int width_pts, int height_pts);
    void* page_info_builder_build(void* builder);
    void page_info_free(void* info);
    void* pdf_document_start_page(void* doc, void* info);
    void pdf_document_finish_page(void* doc, void* page);
}
