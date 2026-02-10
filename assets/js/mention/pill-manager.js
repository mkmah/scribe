// Mention pill creation and manipulation

import { getCaretPosition, getNodeAndOffsetAtPosition, ensureValidCursor, getCursorRelativeToNode } from "./cursor-manager.js"
import { cleanupEmptyNodes, updatePlaceholderVisibility } from "./dom-utils.js"

/**
 * Create a mention pill DOM element
 * @param {string} name - Participant name
 * @returns {HTMLElement} - Pill element
 */
export function createPillElement(name) {
    // Trim whitespace to avoid display issues
    const trimmedName = name.trim()

    const wrapper = document.createElement("span")
    wrapper.className = "mention-pill"
    wrapper.contentEditable = "false"
    wrapper.dataset.mention = trimmedName

    const avatar = document.createElement("span")
    avatar.className = "mention-pill-avatar"
    avatar.textContent = trimmedName.charAt(0).toUpperCase()

    const nameSpan = document.createElement("span")
    nameSpan.textContent = trimmedName

    wrapper.appendChild(avatar)
    wrapper.appendChild(nameSpan)

    return wrapper
}

/**
 * Insert pill and space, then position cursor after space
 * @param {HTMLElement} element - Contenteditable element
 * @param {HTMLElement} pill - Pill element
 * @param {Range} range - Range to insert at, or null to append at end
 */
function insertPillWithSpace(element, pill, range = null) {
    const spaceNode = document.createTextNode(" ")
    
    if (range) {
        range.insertNode(pill)
        const afterRange = document.createRange()
        afterRange.setStartAfter(pill)
        afterRange.collapse(true)
        afterRange.insertNode(spaceNode)
        // Position cursor after space
        const cursorRange = document.createRange()
        cursorRange.setStartAfter(spaceNode)
        cursorRange.collapse(true)
        const selection = window.getSelection()
        selection.removeAllRanges()
        selection.addRange(cursorRange)
    } else {
        // Append at end
        element.appendChild(pill)
        element.appendChild(spaceNode)
        const cursorRange = document.createRange()
        cursorRange.setStartAfter(spaceNode)
        cursorRange.collapse(true)
        const selection = window.getSelection()
        selection.removeAllRanges()
        selection.addRange(cursorRange)
    }
}

/**
 * Insert a pill at the end of the element
 * @param {HTMLElement} element - Contenteditable element
 * @param {string} name - Participant name
 * @returns {Array} - Updated mentions array
 */
export function insertPillAtEnd(element, name) {
    const pill = createPillElement(name)
    insertPillWithSpace(element, pill)
    
    cleanupEmptyNodes(element)
    updatePlaceholderVisibility(element)
    element.focus()
    
    return rebuildMentionsFromDOM(element)
}

/**
 * Insert a pill at the current cursor position
 * @param {HTMLElement} element - Contenteditable element
 * @param {string} name - Participant name
 * @param {number} atSymbolIndex - Index of @ symbol, or -1 to insert at cursor
 * @returns {Array} - Updated mentions array
 */
export function insertPillAtCursor(element, name, atSymbolIndex = -1) {
    const cursorPos = getCaretPosition(element)
    const startIndex = atSymbolIndex === -1 ? cursorPos : atSymbolIndex
    const pill = createPillElement(name)
    const range = document.createRange()

    cleanupEmptyNodes(element)

    if (startIndex === cursorPos) {
        // Insert at cursor - preserve existing content
        const start = getNodeAndOffsetAtPosition(element, startIndex)
        if (!start) return rebuildMentionsFromDOM(element)
        range.setStart(start.node, start.offset)
        range.collapse(true)
    } else {
        // Replace @ trigger text
        const start = getNodeAndOffsetAtPosition(element, startIndex)
        const end = getNodeAndOffsetAtPosition(element, cursorPos)
        if (!start || !end) return rebuildMentionsFromDOM(element)
        range.setStart(start.node, start.offset)
        range.setEnd(end.node, end.offset)
        range.deleteContents()
    }

    insertPillWithSpace(element, pill, range)
    cleanupEmptyNodes(element)
    updatePlaceholderVisibility(element)
    element.focus()
    
    return rebuildMentionsFromDOM(element)
}

/**
 * Remove a pill and cleanup trailing space
 * @param {HTMLElement} element - Contenteditable element
 * @param {HTMLElement} pill - Pill element to remove
 */
export function removePill(element, pill) {
    // Remove trailing space if it exists (inserted with pill)
    const nextSibling = pill.nextSibling
    if (nextSibling && nextSibling.nodeType === Node.TEXT_NODE && nextSibling.textContent.trim() === "") {
        nextSibling.remove()
    }
    pill.remove()
    
    // Rebuild mentions array from remaining pills
    rebuildMentionsFromDOM(element)
    cleanupEmptyNodes(element)
    ensureValidCursor(element)
    updatePlaceholderVisibility(element)
}

/**
 * Rebuild mentions array from DOM pills
 * @param {HTMLElement} element - Contenteditable element
 * @returns {Array} - Mentions array
 */
export function rebuildMentionsFromDOM(element) {
    const pills = element.querySelectorAll(".mention-pill")
    const mentions = []
    pills.forEach((pill, index) => {
        const name = pill.dataset.mention
        if (name) {
            mentions.push({ name, index })
        }
    })
    element.dataset.mentions = mentions.map(m => m.name).join(",")
    return mentions
}

/**
 * Check if cursor is inside a mention pill
 * @param {HTMLElement} element - Contenteditable element
 * @returns {boolean} - True if cursor is in a pill
 */
export function isCursorInMention(element) {
    const selection = window.getSelection()
    if (!selection.rangeCount) return false

    const range = selection.getRangeAt(0)
    let node = range.startContainer

    // Check if cursor is within or after a mention pill
    while (node && node !== element) {
        if (node.classList?.contains("mention-pill")) {
            return true
        }
        node = node.parentNode
    }
    return false
}

/**
 * Skip whitespace-only text nodes
 * @param {Node} node - Starting node
 * @returns {Node | null} - First non-whitespace node or null
 */
function skipWhitespaceNodes(node) {
    while (node && node.nodeType === Node.TEXT_NODE && node.textContent.trim() === "") {
        node = node.previousSibling
    }
    return node
}

/**
 * Find pill immediately before cursor (for backspace handling)
 * Simplified: Check common cases, fallback to complex traversal
 * @param {HTMLElement} element - Contenteditable element
 * @returns {HTMLElement | null} - Pill element or null
 */
export function getNodeImmediatelyBeforeCursor(element) {
    const selection = window.getSelection()
    if (!selection.rangeCount) return null
    const range = selection.getRangeAt(0)
    if (!range.collapsed || !element.contains(range.startContainer)) return null

    const sc = range.startContainer
    const so = range.startOffset

    // Case 1: Cursor at start of text node
    if (sc.nodeType === Node.TEXT_NODE && so === 0) {
        const prev = skipWhitespaceNodes(sc.previousSibling)
        if (prev?.classList?.contains("mention-pill")) return prev
        if (prev?.nodeType === Node.ELEMENT_NODE) return prev.querySelector(".mention-pill") || null
        return null
    }

    // Case 2: Cursor in text node with only whitespace before it
    if (sc.nodeType === Node.TEXT_NODE && so > 0) {
        if (/^\s*$/.test(sc.textContent.slice(0, so))) {
            const prev = skipWhitespaceNodes(sc.previousSibling)
            if (prev?.classList?.contains("mention-pill")) return prev
        }
        return null
    }

    // Case 3: Cursor in element node
    if (sc.nodeType === Node.ELEMENT_NODE && so > 0) {
        const prev = sc.childNodes[so - 1]
        if (prev?.classList?.contains("mention-pill")) return prev
        if (prev?.nodeType === Node.ELEMENT_NODE) {
            return prev.querySelector(".mention-pill") || null
        }
    }
    
    return null
}

/**
 * Find pill at cursor position (before or after)
 * Simplified: Check all pills for cursor position, fallback to complex check
 * @param {HTMLElement} element - Contenteditable element
 * @returns {HTMLElement | null} - Pill element or null
 */
export function findPillAtCursor(element) {
    const selection = window.getSelection()
    if (!selection.rangeCount) return null
    const range = selection.getRangeAt(0)
    if (!range.collapsed || !element.contains(range.startContainer)) return null

    // Check all pills for cursor position relative to them
    const pills = Array.from(element.querySelectorAll(".mention-pill"))
    for (const pill of pills) {
        const position = getCursorRelativeToNode(element, pill)
        if (position === 'before' || position === 'after') {
            return pill
        }
    }
    
    // Fallback: use the more complex check for edge cases
    return getNodeImmediatelyBeforeCursor(element)
}
