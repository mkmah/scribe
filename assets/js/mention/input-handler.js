// Input event handling and @ symbol detection

import { getCaretPosition } from "./cursor-manager.js"
import { updatePlaceholderVisibility } from "./dom-utils.js"
import { isCursorInMention } from "./pill-manager.js"

/**
 * Detect @ mention trigger before cursor
 * @param {string} text - Full text content
 * @param {number} cursorPos - Cursor position
 * @returns {{match: string, filter: string, index: number} | null} - Match info or null
 */
export function detectMentionTrigger(text, cursorPos) {
    const textBeforeCursor = text.substring(0, cursorPos)
    const atMatch = textBeforeCursor.match(/@(\w*)$/)
    
    if (atMatch) {
        return {
            match: atMatch[0],
            filter: atMatch[1],
            index: cursorPos - atMatch[0].length
        }
    }
    
    return null
}

/**
 * Handle input event
 * @param {HTMLElement} element - Contenteditable element
 * @param {Event} event - Input event
 * @param {Function} getTextContent - Function to get text content
 * @param {Object} callbacks - Callback functions
 * @param {Function} callbacks.onMentionTrigger - Called when @ is detected
 * @param {Function} callbacks.onInput - Called on any input
 * @param {Object} state - State object
 */
export function handleInput(element, event, getTextContent, callbacks, state) {
    const text = getTextContent()
    const cursorPos = getCaretPosition(element)
    
    // Find @ symbol before cursor
    const trigger = detectMentionTrigger(text, cursorPos)
    
    if (trigger && !isCursorInMention(element)) {
        callbacks.onMentionTrigger?.(trigger.filter, trigger.index)
    } else {
        callbacks.onMentionHide?.()
    }
    
    // Update placeholder visibility after input
    updatePlaceholderVisibility(element)
    
    // Clear stored content if user is typing (they're modifying content)
    // This prevents restoration after user intentionally clears content
    if (state && state.storedContent && !state.isInserting) {
        state.storedContent = null
    }
}
