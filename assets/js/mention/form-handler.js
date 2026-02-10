// Form submission, content syncing, and clearing logic

import { extractTextWithMentions, updatePlaceholderVisibility } from "./dom-utils.js"
import { storeContentState } from "./content-restorer.js"
import { hideMenu } from "./menu-manager.js"

/**
 * Load participants from form data attribute
 * @param {HTMLElement} element - Contenteditable element
 * @returns {Array} - Array of participant objects
 */
export function loadParticipants(element) {
    const form = element.closest("form")
    if (!form || !form.dataset.participants) return []
    try {
        return JSON.parse(form.dataset.participants)
    } catch (e) {
        console.error("Failed to parse participants data:", e)
        return []
    }
}

/**
 * Get participants from form (reads current list, updated by LiveView)
 * @param {HTMLElement} element - Contenteditable element
 * @returns {Array} - Array of participant objects
 */
export function getParticipants(element) {
    const form = element.closest("form")
    if (!form || !form.dataset.participants) return []
    try {
        return JSON.parse(form.dataset.participants)
    } catch (_) {
        return []
    }
}

/**
 * Sync content from contenteditable to hidden input
 * @param {HTMLElement} textarea - Contenteditable element
 * @param {HTMLElement} hiddenInput - Hidden input element
 */
export function syncContentToHiddenInput(textarea, hiddenInput) {
    if (!textarea || !hiddenInput) return
    const text = extractTextWithMentions(textarea).trim()
    hiddenInput.value = text || ""
}

/**
 * Clear input element (visual and optionally hidden input)
 * @param {HTMLElement} element - Contenteditable element
 * @param {Object} state - State object with mentions, menu state, etc.
 * @param {boolean} clearHidden - Whether to clear hidden input too
 */
export function clearInput(element, state, clearHidden = true) {
    // Clear the contenteditable div
    element.innerHTML = ""
    
    // Reset mentions array
    if (state.mentions) {
        state.mentions = []
    }
    
    // Reset state
    if (state.atSymbolIndex !== undefined) state.atSymbolIndex = -1
    if (state.selectedIndex !== undefined) state.selectedIndex = 0
    if (state.isMenuVisible !== undefined) state.isMenuVisible = false
    
    // Update placeholder visibility
    updatePlaceholderVisibility(element)
    
    // Clear the hidden input value if requested
    if (clearHidden) {
        const hiddenInput = document.getElementById("chat-popup-message-input")
        if (hiddenInput) {
            hiddenInput.value = ""
        }
    }
    
    // Hide mention menu if visible
    hideMenu()
    
    // Reset cursor position
    const selection = window.getSelection()
    if (selection.rangeCount) {
        const range = document.createRange()
        range.selectNodeContents(element)
        range.collapse(true)
        selection.removeAllRanges()
        selection.addRange(range)
    }
}

/**
 * Setup form event listeners for content storage and submission
 * @param {HTMLElement} element - Contenteditable element
 * @param {Function} getTextContent - Function to get text content
 * @param {Object} state - State object
 * @param {Function} onClearInput - Callback to clear input
 */
export function setupFormListeners(element, getTextContent, state, onClearInput) {
    const form = element.closest("form")
    if (!form) return

    // Store content state before events that cause LiveView re-renders
    const addContextBtn = form.querySelector('[phx-click="toggle_context_menu"]')
    if (addContextBtn) {
        addContextBtn.addEventListener("click", () => {
            state.storedContent = storeContentState(element, getTextContent)
        })
    }

    // Also store content when clicking participant items in context menu
    form.addEventListener("click", (e) => {
        const participantBtn = e.target.closest('[phx-click="add_participant_context"]')
        if (participantBtn) {
            // Store content state BEFORE LiveView processes the click
            state.storedContent = storeContentState(element, getTextContent)
            state.isInserting = true
            // Clear the flag after a delay to allow insertion to complete
            setTimeout(() => {
                state.isInserting = false
            }, 1000)
        }
    })

    // Clear visual input on form submission (for submit button clicks)
    form.addEventListener("submit", () => {
        // Only clear visual parts if form is actually submitting (not prevented)
        // Use a small delay to ensure the form submission proceeds
        setTimeout(() => {
            if (form.hasAttribute("data-submitting")) {
                onClearInput(false) // Don't clear hidden input here
            }
        }, 50)
    })
}

/**
 * Handle form submission - sync content and validate
 * @param {HTMLElement} hiddenInput - Hidden input element
 * @param {HTMLElement} textarea - Contenteditable element
 * @param {HTMLElement} form - Form element
 * @returns {boolean} - True if submission should proceed
 */
export function handleFormSubmit(hiddenInput, textarea, form) {
    // Prevent duplicate submissions
    if (form.hasAttribute("data-submitting")) {
        return false
    }
    
    // Sync content before submit
    syncContentToHiddenInput(textarea, hiddenInput)
    
    // Check if message is empty after syncing
    if (!hiddenInput.value || !hiddenInput.value.trim()) {
        return false
    }
    
    // Mark form as submitting
    form.setAttribute("data-submitting", "true")
    
    // Clear the visual textarea immediately (for UX)
    // But DON'T clear the hidden input yet - let the form submit with the value
    if (textarea) {
        textarea.innerHTML = ""
        updatePlaceholderVisibility(textarea)
        
        // Reset cursor position
        const selection = window.getSelection()
        if (selection.rangeCount) {
            const range = document.createRange()
            range.selectNodeContents(textarea)
            range.collapse(true)
            selection.removeAllRanges()
            selection.addRange(range)
        }
    }
    
    // Clear hidden input AFTER form submission completes
    // Use setTimeout to ensure form has submitted before clearing
    setTimeout(() => {
        hiddenInput.value = ""
        form.removeAttribute("data-submitting")
    }, 100)
    
    return true
}
