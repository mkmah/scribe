// DOM traversal and text extraction utilities for mention input

/**
 * Extract text content from a DOM node, replacing mention pills with @name
 * @param {Node} node - The DOM node to extract text from
 * @returns {string} - Plain text with mentions as @name
 */
export function extractTextWithMentions(node) {
    const traverse = (n) => {
        if (n.nodeType === Node.TEXT_NODE) return n.textContent
        if (n.classList?.contains("mention-pill")) return "@" + (n.dataset.mention || "")
        let s = ""
        for (const child of n.childNodes) s += traverse(child)
        return s
    }
    return traverse(node)
}

/**
 * Extract text content from HTML string (excluding pills)
 * @param {string} html - HTML string to extract text from
 * @returns {string} - Plain text without pills
 */
export function getTextContentFromHTML(html) {
    const div = document.createElement("div")
    div.innerHTML = html
    // Remove all mention pills
    div.querySelectorAll(".mention-pill").forEach(pill => pill.remove())
    return div.textContent.trim()
}

/**
 * Check if element is truly empty (no pills, no non-whitespace text)
 * @param {HTMLElement} element - Element to check
 * @returns {boolean} - True if empty
 */
export function isTrulyEmpty(element) {
    const hasPills = element.querySelector(".mention-pill") !== null
    if (hasPills) return false

    // Treat any existing text node (even whitespace-only) as real user content.
    // This ensures that typing a space clears the placeholder instead of
    // rendering it alongside the placeholder text.
    const walker = document.createTreeWalker(
        element,
        NodeFilter.SHOW_TEXT,
        null
    )

    let node
    while (node = walker.nextNode()) {
        if (node.textContent && node.textContent.length > 0) {
            return false
        }
    }

    return true
}

/**
 * Update placeholder visibility based on content
 * @param {HTMLElement} element - Element to update
 */
export function updatePlaceholderVisibility(element) {
    const isEmpty = isTrulyEmpty(element)
    if (isEmpty) {
        element.setAttribute("data-empty", "true")
    } else {
        element.removeAttribute("data-empty")
    }
}

/**
 * Clean up empty text nodes to ensure :empty pseudo-class works
 * Preserves user-typed spaces and line breaks (<br>)
 * @param {HTMLElement} element - Element to clean up
 */
export function cleanupEmptyNodes(element) {
    const textNodes = []
    const walker = document.createTreeWalker(
        element,
        NodeFilter.SHOW_TEXT,
        null
    )

    let node
    while (node = walker.nextNode()) {
        textNodes.push(node)
    }

    // Check if there's any real content (pills or non-whitespace text)
    const hasPills = element.querySelector(".mention-pill") !== null
    const hasNonWhitespaceText = textNodes.some(tn => tn.textContent.trim() !== "")

    // Only clean up if there's no real content
    if (!hasPills && !hasNonWhitespaceText) {
        // Remove all empty text nodes and <br> elements when truly empty
        textNodes.forEach(textNode => {
            if (textNode.textContent === "") {
                textNode.remove()
            }
        })
        element.querySelectorAll('br').forEach(br => br.remove())
    } else {
        // When there's content, only remove truly empty nodes (not whitespace-only)
        textNodes.forEach(textNode => {
            if (textNode.textContent === "") {
                textNode.remove()
            }
        })
        // Preserve <br> elements when there's content (they're line breaks)
    }
    
    // Update placeholder visibility after cleanup
    updatePlaceholderVisibility(element)
}
