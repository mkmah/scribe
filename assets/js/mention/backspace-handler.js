// Backspace key handling for pill deletion

import { findPillAtCursor, removePill, rebuildMentionsFromDOM } from "./pill-manager.js"
import { isTrulyEmpty, updatePlaceholderVisibility } from "./dom-utils.js"

/**
 * Handle backspace key press
 * @param {HTMLElement} element - Contenteditable element
 * @param {KeyboardEvent} event - Keyboard event
 * @param {Object} state - State object with storedContent and mentions
 * @returns {boolean} - True if handled (prevented default)
 */
export function handleBackspace(element, event, state) {
    const selection = window.getSelection()
    if (!selection.rangeCount) return false
    const range = selection.getRangeAt(0)
    if (!element.contains(range.startContainer)) return false

    // Find pill at cursor position (unified check for all scenarios)
    const pill = findPillAtCursor(element)
    
    if (pill) {
        event.preventDefault()
        removePill(element, pill)
        
        // Update mentions array in state
        if (state && state.mentions) {
            state.mentions = rebuildMentionsFromDOM(element)
        }
        
        // Clear stored content if everything is deleted
        if (isTrulyEmpty(element)) {
            if (state) {
                state.storedContent = null
            }
        }
        
        return true
    }
    
    // Handle regular backspace - check if content becomes empty after deletion
    // Use setTimeout to check after the browser's default backspace behavior
    setTimeout(() => {
        updatePlaceholderVisibility(element)
        // Clear stored content if everything is deleted
        if (isTrulyEmpty(element) && state) {
            state.storedContent = null
        }
    }, 0)
    
    return false
}
