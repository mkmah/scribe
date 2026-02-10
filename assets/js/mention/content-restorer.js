// Content restoration across LiveView updates

import { rebuildMentionsFromDOM } from "./pill-manager.js"
import { updatePlaceholderVisibility } from "./dom-utils.js"

/**
 * Store content state before LiveView update
 * @param {HTMLElement} element - Contenteditable element
 * @param {Function} getTextContent - Function to get text content
 * @returns {string | null} - Stored HTML content or null
 */
export function storeContentState(element, getTextContent) {
    const currentHTML = element.innerHTML
    const hasContent = getTextContent().trim() || element.querySelector(".mention-pill")
    return hasContent ? currentHTML : null
}

/**
 * Restore content and place cursor at end
 * @param {HTMLElement} element - Contenteditable element
 * @param {string} storedContent - Stored HTML content
 */
export function restoreContent(element, storedContent) {
    if (!storedContent) return
    
    element.innerHTML = storedContent
    // Rebuild mentions from restored DOM
    rebuildMentionsFromDOM(element)
    
    // Place cursor at end
    requestAnimationFrame(() => {
        const range = document.createRange()
        range.selectNodeContents(element)
        range.collapse(false) // Collapse to end
        const selection = window.getSelection()
        selection.removeAllRanges()
        selection.addRange(range)
        updatePlaceholderVisibility(element)
    })
}

/**
 * Setup mutation observer to watch for LiveView DOM changes
 * Since phx-update="ignore" is set, LiveView shouldn't modify the element.
 * This observer only handles our own mutations (pill insertions).
 * @param {HTMLElement} element - Contenteditable element
 * @param {Object} callbacks - Callback functions
 * @param {Function} callbacks.onRestore - Called when content is restored
 * @returns {MutationObserver} - Observer instance
 */
export function setupMutationObserver(element, callbacks) {
    const { onRestore } = callbacks
    
    const observer = new MutationObserver((mutations) => {
        // Check if we added mention pills (our own insertion)
        const hasPillInsertion = mutations.some(mutation => 
            mutation.type === 'childList' && 
            Array.from(mutation.addedNodes).some(node => 
                node.nodeType === Node.ELEMENT_NODE && 
                (node.classList?.contains("mention-pill") || node.querySelector?.(".mention-pill"))
            )
        )
        
        if (hasPillInsertion) {
            // Rebuild mentions and update placeholder visibility
            rebuildMentionsFromDOM(element)
            updatePlaceholderVisibility(element)
        } else {
            // Just update placeholder visibility for other changes
            updatePlaceholderVisibility(element)
        }
    })

    observer.observe(element, {
        childList: true,
        characterData: true,
        subtree: true
    })
    
    return observer
}
