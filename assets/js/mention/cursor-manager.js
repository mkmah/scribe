// Cursor position management utilities

/**
 * Get current cursor position as character offset
 * @param {HTMLElement} element - Contenteditable element
 * @returns {number} - Character offset position
 */
export function getCaretPosition(element) {
    const selection = window.getSelection()
    if (!selection.rangeCount) return 0

    const range = selection.getRangeAt(0)
    const preCaretRange = range.cloneRange()
    preCaretRange.selectNodeContents(element)
    preCaretRange.setEnd(range.endContainer, range.endOffset)
    return preCaretRange.toString().length
}

/**
 * Set cursor to specific character position
 * @param {HTMLElement} element - Contenteditable element
 * @param {number} pos - Character offset position
 */
export function setCaretPosition(element, pos) {
    const range = document.createRange()
    const selection = window.getSelection()

    let charCount = 0
    let found = false

    const traverse = (node) => {
        if (found) return

        if (node.nodeType === Node.TEXT_NODE) {
            const nextCount = charCount + node.length
            if (pos <= nextCount) {
                range.setStart(node, pos - charCount)
                range.collapse(true)
                found = true
            }
            charCount = nextCount
        } else {
            for (const child of node.childNodes) {
                traverse(child)
                if (found) return
            }
        }
    }

    traverse(element)

    if (!found) {
        range.selectNodeContents(element)
        range.collapse(false)
    }

    selection.removeAllRanges()
    selection.addRange(range)
}

/**
 * Get cursor screen coordinates for dropdown positioning
 * @param {HTMLElement} element - Contenteditable element
 * @returns {{left: number, top: number, bottom: number}} - Cursor coordinates
 */
export function getCaretCoordinates(element) {
    const selection = window.getSelection()
    if (!selection.rangeCount) {
        return getFallbackCoordinates(element)
    }

    const range = selection.getRangeAt(0)
    const rects = range.getClientRects()

    if (rects.length > 0) {
        const rect = rects[0]
        const coords = { left: rect.left, top: rect.top, bottom: rect.bottom }
        
        // Check if coordinates are valid (not 0,0 and within reasonable bounds)
        if (isValidCoordinates(coords, element)) {
            return coords
        }
    }

    // Try bounding rect as fallback
    const rect = range.getBoundingClientRect()
    const coords = { left: rect.left, top: rect.top, bottom: rect.bottom }
    
    if (isValidCoordinates(coords, element)) {
        return coords
    }

    // Final fallback: calculate from element position
    return getFallbackCoordinates(element)
}

/**
 * Check if coordinates are valid (not 0,0 and within reasonable bounds)
 * @param {{left: number, top: number, bottom: number}} coords - Coordinates to validate
 * @param {HTMLElement} element - Contenteditable element
 * @returns {boolean} - Whether coordinates are valid
 */
function isValidCoordinates(coords, element) {
    // Check if coordinates are not (0,0) or very small values
    if (coords.left < 1 && coords.top < 1) {
        return false
    }
    
    // Check if coordinates are within viewport bounds (with some margin)
    const viewportWidth = window.innerWidth
    const viewportHeight = window.innerHeight
    
    // Coordinates should be within reasonable bounds of the viewport
    if (coords.left > viewportWidth + 100 || coords.top > viewportHeight + 100) {
        return false
    }
    
    // Check if coordinates are reasonably close to the element
    const elementRect = element.getBoundingClientRect()
    const horizontalDistance = Math.abs(coords.left - elementRect.left)
    const verticalDistance = Math.abs(coords.top - elementRect.top)
    
    // If coordinates are too far from element (more than 2x element width/height), likely invalid
    if (horizontalDistance > elementRect.width * 2 || verticalDistance > elementRect.height * 2) {
        return false
    }
    
    return true
}

/**
 * Get fallback coordinates from element position when caret coordinates are invalid
 * @param {HTMLElement} element - Contenteditable element
 * @returns {{left: number, top: number, bottom: number}} - Fallback coordinates
 */
function getFallbackCoordinates(element) {
    const elementRect = element.getBoundingClientRect()
    const styles = window.getComputedStyle(element)
    
    // Get padding values
    const paddingLeft = parseFloat(styles.paddingLeft) || 0
    const paddingTop = parseFloat(styles.paddingTop) || 0
    
    // Calculate position at start of content (left edge + padding, top edge + padding)
    // For empty or near-empty elements, this approximates where the caret would be
    const left = elementRect.left + paddingLeft
    const top = elementRect.top + paddingTop
    
    // Estimate line height for bottom coordinate
    const lineHeight = parseFloat(styles.lineHeight) || parseFloat(styles.fontSize) || 16
    const bottom = top + lineHeight
    
    return { left, top, bottom }
}

/**
 * Convert character position to DOM node/offset
 * @param {HTMLElement} element - Contenteditable element
 * @param {number} pos - Character offset position
 * @returns {{node: Node, offset: number} | null} - Node and offset, or null if not found
 */
export function getNodeAndOffsetAtPosition(element, pos) {
    let charCount = 0
    let result = null
    const traverse = (node) => {
        if (result) return
        if (node.nodeType === Node.TEXT_NODE) {
            const nextCount = charCount + node.length
            if (pos <= nextCount) {
                result = { node, offset: pos - charCount }
            }
            charCount = nextCount
        } else if (node.classList && node.classList.contains("mention-pill")) {
            const len = 1 + (node.dataset.mention || "").length
            const nextCount = charCount + len
            if (pos <= nextCount) {
                const parent = node.parentNode
                const index = Array.from(parent.childNodes).indexOf(node)
                result = { node: parent, offset: pos <= charCount ? index : index + 1 }
            }
            charCount = nextCount
        } else {
            for (const child of node.childNodes) {
                traverse(child)
                if (result) return
            }
        }
    }
    traverse(element)
    if (!result) {
        const last = element.lastChild
        if (last) {
            if (last.nodeType === Node.TEXT_NODE) result = { node: last, offset: last.length }
            else result = { node: element, offset: element.childNodes.length }
        } else {
            result = { node: element, offset: 0 }
        }
    }
    return result
}

/**
 * Ensure cursor is in a valid position after DOM changes
 * @param {HTMLElement} element - Contenteditable element
 */
export function ensureValidCursor(element) {
    const selection = window.getSelection()
    if (!selection.rangeCount) {
        const newRange = document.createRange()
        newRange.selectNodeContents(element)
        newRange.collapse(true)
        selection.addRange(newRange)
        return
    }

    const currentRange = selection.getRangeAt(0)
    const startContainer = currentRange.startContainer

    // If cursor is in a removed node or invalid position, reposition it
    if (!element.contains(startContainer) || (startContainer.nodeType === Node.ELEMENT_NODE && startContainer.classList?.contains("mention-pill"))) {
        // Place cursor at end of content or start if empty
        const newRange = document.createRange()
        if (element.childNodes.length === 0) {
            newRange.setStart(element, 0)
            newRange.collapse(true)
        } else {
            const lastNode = element.lastChild
            if (lastNode.nodeType === Node.TEXT_NODE) {
                newRange.setStart(lastNode, lastNode.length)
            } else {
                newRange.setStartAfter(lastNode)
            }
            newRange.collapse(true)
        }
        selection.removeAllRanges()
        selection.addRange(newRange)
    }
}

/**
 * Get cursor position relative to a node
 * @param {HTMLElement} element - Contenteditable element
 * @param {Node} node - Node to check position relative to
 * @returns {'before' | 'after' | null} - Position relative to node
 */
export function getCursorRelativeToNode(element, node) {
    const selection = window.getSelection()
    if (!selection.rangeCount) return null
    
    const range = selection.getRangeAt(0)
    if (!range.collapsed) return null
    
    // Check if cursor is before the node (no content between cursor and node start)
    const beforeRange = range.cloneRange()
    beforeRange.setStartBefore(node)
    beforeRange.setEnd(range.startContainer, range.startOffset)
    if (beforeRange.toString().trim() === '') {
        return 'before'
    }
    
    // Check if cursor is after the node (no content between node end and cursor)
    const afterRange = range.cloneRange()
    afterRange.setStartAfter(node)
    afterRange.setEnd(range.startContainer, range.startOffset)
    if (afterRange.toString().trim() === '') {
        return 'after'
    }
    
    return null
}
