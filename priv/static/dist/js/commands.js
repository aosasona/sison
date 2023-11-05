import * as toast from "./toast.js";
import * as markupfns from "./markup.js";
export class Commands {
    constructor(editor) {
        this.editor = editor;
    }
    toggleSidebar() {
        const sidebar = document.getElementById("sidebar");
        if (!sidebar)
            return;
        const sidebarToggle = document.getElementById("sidebar-toggle");
        const sidebarToggleIcon = sidebarToggle === null || sidebarToggle === void 0 ? void 0 : sidebarToggle.querySelector("i");
        if (!sidebarToggle)
            return;
        const status = sidebar.dataset.status;
        if (status === "open") {
            sidebar === null || sidebar === void 0 ? void 0 : sidebar.classList.remove("sidebar-opened");
            sidebar === null || sidebar === void 0 ? void 0 : sidebar.classList.add("sidebar-closed");
            sidebar === null || sidebar === void 0 ? void 0 : sidebar.setAttribute("data-status", "closed");
            sidebarToggleIcon === null || sidebarToggleIcon === void 0 ? void 0 : sidebarToggleIcon.classList.remove("ti-layout-sidebar-right-expand");
            sidebarToggleIcon === null || sidebarToggleIcon === void 0 ? void 0 : sidebarToggleIcon.classList.add("ti-layout-sidebar-left-expand");
        }
        else {
            sidebar === null || sidebar === void 0 ? void 0 : sidebar.classList.remove("sidebar-closed");
            sidebar === null || sidebar === void 0 ? void 0 : sidebar.classList.add("sidebar-opened");
            sidebar === null || sidebar === void 0 ? void 0 : sidebar.setAttribute("data-status", "open");
            sidebarToggleIcon === null || sidebarToggleIcon === void 0 ? void 0 : sidebarToggleIcon.classList.remove("ti-layout-sidebar-left-expand");
            sidebarToggleIcon === null || sidebarToggleIcon === void 0 ? void 0 : sidebarToggleIcon.classList.add("ti-layout-sidebar-right-expand");
        }
    }
    saveDocument() {
        const document_id = this.editor.dataset.documentId;
        if (!document_id)
            return toast.error("No document ID found, please refresh the page and try again");
        const content = this.editor.value;
        if (!content)
            return toast.error("No content found!");
        if (!this.isValidJSON(content))
            return toast.error("Invalid JSON");
        const description = this.editor.dataset.description;
        fetch("/documents", {
            method: "PUT",
            headers: {
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ document_id, content, description }),
        })
            .then((res) => res.json())
            .then((data) => {
            var _a, _b;
            if (data === null || data === void 0 ? void 0 : data.ok) {
                toast.success("Document saved");
                if ((_a = data === null || data === void 0 ? void 0 : data.data) === null || _a === void 0 ? void 0 : _a.content)
                    this.editor.value = data.data.content;
                this.updatePreview({ showToast: false });
                // Update document ID in URL if it isn't already present (e.g. when creating a new document)
                if (!window.location.href.includes((_b = data.data) === null || _b === void 0 ? void 0 : _b.document_id)) {
                    window.history.replaceState(null, "", `/e/${data.data.document_id}`);
                }
                return;
            }
            toast.error((data === null || data === void 0 ? void 0 : data.error) || "An unknown error occurred");
        })
            .catch((err) => {
            toast.error(err);
        });
    }
    updatePreview({ showToast } = { showToast: true }) {
        const doc = this.editor.value;
        if (!doc) {
            return;
        }
        const jsonDoc = markupfns._safeJSONParse(doc);
        if (!jsonDoc) {
            return;
        }
        // Update text editor with formatted JSON
        this.editor.value = JSON.stringify(jsonDoc, null, 2);
        // Update preview
        const markup = markupfns.toMarkUp(jsonDoc);
        const preview = document.querySelector("#preview");
        if (preview) {
            preview.innerHTML = markup;
        }
        if (showToast) {
            toast.success("Preview updated");
        }
    }
    isValidJSON(text) {
        try {
            JSON.parse(text);
            return true;
        }
        catch (e) {
            return false;
        }
    }
}
