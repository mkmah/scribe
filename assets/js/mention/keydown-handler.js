// Consolidated keyboard event handling

import { handleBackspace } from "./backspace-handler.js"
import { handleKeyboardNavigation } from "./menu-manager.js"
import { extractTextWithMentions } from "./dom-utils.js"

/**
 * Handle all keydown events for mention input
 * @param {KeyboardEvent} e - Keyboard event
 * @param {HTMLElement} element - Contenteditable element
 * @param {Object} state - State object with menu visibility, selectedIndex, etc.
 * @param {Function} getTextContent - Function to get text content
 * @param {Function} onInsertMention - Callback when mention should be inserted
 * @param {Function} onSubmit - Callback when form should be submitted
 * @returns {boolean} - True if event was handled
 */
export function handleKeydown(e, element, state, getTextContent, onInsertMention, onSubmit) {
    // When mention menu is visible, handle navigation keys
    if (state.isMenuVisible) {
        // Prevent form submission with Enter when menu is visible
        if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault()
            e.stopPropagation()
        }

        const dropdown = document.getElementById("mention-dropdown")
        if (dropdown) {
            const items = dropdown.querySelectorAll(".mention-dropdown-item")
            const result = handleKeyboardNavigation(e.key, items, state.selectedIndex || 0, (name) => {
                onInsertMention(name)
            })
            
            if (result.handled) {
                if (result.newIndex !== undefined) {
                    state.selectedIndex = result.newIndex
                }
                if (e.key === "Escape") {
                    state.isMenuVisible = false
                }
                return true
            }
        }
    }

    // Handle Shift+Enter for new lines
    if (e.key === "Enter" && e.shiftKey) {
        e.preventDefault()
        const selection = window.getSelection()
        if (selection.rangeCount) {
            const range = selection.getRangeAt(0)
            const br = document.createElement("br")
            range.insertNode(br)

            // Add another <br> after if at end of container to ensure line break is visible
            const nextNode = br.nextSibling
            if (!nextNode || (nextNode.nodeType === Node.TEXT_NODE && nextNode.textContent === "")) {
                const extraBr = document.createElement("br")
                br.parentNode.insertBefore(extraBr, br.nextSibling)
                range.setStartAfter(br)
                range.setEndBefore(extraBr)
            } else {
                range.setStartAfter(br)
                range.collapse(true)
            }
            selection.removeAllRanges()
            selection.addRange(range)
        }
        return true
    }

    // Handle Enter (without shift) to submit form if message is not empty
    if (e.key === "Enter" && !e.shiftKey) {
        e.preventDefault()
        e.stopPropagation()
        
        const text = getTextContent().trim()
        if (!text) return true
        
        // Call submit handler
        onSubmit()
        return true
    }

    // Handle backspace to delete mention pills
    if (e.key === "Backspace") {
        return handleBackspace(element, e, state)
    }

    return false
}
