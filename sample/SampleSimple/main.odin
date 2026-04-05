package main

import "core:c"
import "core:fmt"

main :: proc() {
	doc := pdf_document_create()

	page := pdf_document_add_page(doc, 595.0, 842.0)

	pdf_document_add_embedded_font(doc, "media\\Inkfree.ttf", "InkFree")

	pdf_page_add_text(page, "Hello, PDF 2.0!", 72.0, 750.0, "Helvetica", 24.0, {1, 0, 0})
	pdf_page_add_text(page, "New text with system font", 72.0, 734.0, "Comic Sans MS", 16.0)
	pdf_page_add_text(page, "New text with embedded font", 72.0, 718.0, "InkFree", 12.0)

    local_img : cstring = "media\\logo.png"
    pdf_page_add_image(page, local_img, 72.0, 568.0, 150.0, 150.0)

    pdf_page_add_text(page, "Lorem ipsum dolor sit amet consectetur adipiscing elit congue in maecenas dapibus eget, proin consequat vestibulum ultricies nisl mi curae netus pellentesque lacus semper, nostra duis sociosqu litora vulputate vel nam per nec sapien facilisis. Est risus curae cum purus dis arcu, urna sed cras mus mauris ullamcorper accumsan, senectus phasellus nascetur primis duis. Proin curabitur suspendisse eget pulvinar placerat phasellus enim, mollis maecenas bibendum vestibulum semper ante scelerisque etiam, interdum iaculis porttitor pharetra quam a. Ad viverra tincidunt ullamcorper nullam placerat, scelerisque vel aptent a lectus dignissim, vitae dapibus congue nisl.\n\nId tellus placerat ridiculus rutrum cum lacus facilisis in duis montes nostra, hac phasellus eu ante malesuada massa sem dapibus ornare gravida, nunc donec nulla taciti sociosqu quis volutpat vulputate ultrices penatibus. Himenaeos est netus bibendum hac placerat blandit vivamus auctor, eros pulvinar aliquam semper porttitor purus aenean malesuada torquent, odio sagittis scelerisque suspendisse tempor vehicula primis. Varius nec accumsan feugiat posuere cursus dui viverra porttitor duis potenti, vel hac nunc suspendisse eros proin tristique mollis luctus mi torquent, inceptos fames laoreet habitasse massa iaculis praesent arcu hendrerit. Massa magnis lacinia habitasse taciti nulla litora fringilla mollis, tristique quis ornare congue convallis fusce ultricies fermentum eleifend, eget ligula enim felis tincidunt ut magna.\n\nVivamus curabitur mus senectus imperdiet dictum viverra nascetur, libero himenaeos arcu pretium tincidunt dictumst, nec aliquet magna natoque mi laoreet. Praesent quisque at sodales volutpat felis lobortis, donec rhoncus tincidunt platea lacus porta, ultrices faucibus imperdiet fringilla consequat. Libero at euismod convallis praesent integer rhoncus habitasse magna tempor inceptos porta justo, primis dui pulvinar fermentum ac rutrum nulla habitant senectus elementum.\n\nVel tempus malesuada felis pharetra rutrum commodo aliquam, nostra arcu enim semper auctor sed iaculis, etiam ac mattis torquent litora tristique. Nisl nascetur volutpat curae urna sociosqu mi, accumsan malesuada ullamcorper porttitor tempus lectus felis, torquent eros arcu vitae sociis. Quis lacinia nec congue rutrum leo dictumst risus consequat fusce suspendisse, nulla mauris placerat luctus a enim platea ridiculus.\n\nMetus purus parturient class at euismod enim dictumst a lacinia curae porttitor non, vitae per fringilla semper platea aliquet cursus nisi ante senectus. Malesuada consequat pellentesque proin gravida vivamus taciti, feugiat ullamcorper nunc penatibus blandit lacinia, fusce imperdiet mollis phasellus nibh. Tellus sem habitant tempor et auctor porttitor orci feugiat, massa etiam ultrices commodo varius per semper venenatis, litora metus conubia dapibus integer tincidunt habitasse.", 72.0, 556.0)

	result := pdf_document_write_to_file(doc, "hello.pdf")

	pdf_document_close(doc)
	fmt.println("Done")
}
